import UIKit
import MapboxNavigation
import MapboxCoreNavigation
import MapboxMaps

class OfflineRegionsViewController: UIViewController {

    let accessToken = CredentialsManager.default.accessToken
    var tileStore = TileStore.getInstance()
    let resourceOptions: ResourceOptions!
    
    // Transition button, progress view
    var stateButton: UIButton!
    var tileRegionsTableView: UITableView!
    var stylePackProgressView: UIProgressView!
    var tileRegionProgressView: UIProgressView!
    var progressContainer: UIView!
    var downloadRegionsView: UIView!
    
    var navigationMapView: NavigationMapView!
    
    lazy var offlineManager: OfflineManager = {
        return OfflineManager(resourceOptions: <#T##ResourceOptions#>)
    }()
    
    // Tile region and style pack
    var downloads: [Cancelable] = []
    
    // Create some hard-coded regions
    let washingtonDCCoord = CLLocationCoordinate2D(latitude: 38.907, longitude: -77.036)
    let washingtonDCZoom: CGFloat = 12
    let dcRegionIdentifier = "Washington DC Tile Region"
    
    let sanFranCoord = CLLocationCoordinate2D(latitude: 37.791, longitude: -122.396)
    let sanFranZoom: CGFloat = 12
    let sfRegionIdentifier = "San Francisco Tile Region"
    
    enum State {
        case beforeExampleSelected
        case initial
        case downloading
        case downloaded
        case finished
        case showingNavigationMapView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        state = .initial
    }
    
    func setupRefreshRegionsBarButtonItem() {
        let refreshRegionsBarButtonItem = UIBarButtonItem(title: NSString(string: "\u{1F5FA}") as String,
                                                    style: .plain,
                                                    target: self,
                                                    action: #selector(updateRegions))
        refreshRegionsBarButtonItem.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 30)], for: .normal)
        refreshRegionsBarButtonItem.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 30)], for: .highlighted)
        navigationItem.rightBarButtonItem = refreshRegionsBarButtonItem
    }
    
    func setupTileRegionsTableView() {
        tileRegionsTableView = UITableView()
    }
    
// MARK: Offline Regions
    @objc func updateRegions(_ sender: Any) {
        refreshOutdatedOfflineRegions()
    }
    
    @objc func listRegions(_ sender: Any) {
        tileRegionsTableView.isHidden = false
    }

    func createCustomTileStore() {
        // get access token
        guard let accessToken = CredentialsManager.default.accessToken else {
            fatalError("Access token was not set.")
        }

        // Create a TileStore instance at the default location
        tileStore = TileStore.getInstance()
        let resourceOptions = ResourceOptions(accessToken: accessToken,
                                              tileStore: tileStore)
    }

    func downloadOfflineRegions() {
        // Create style package
        let stylePackLoadOptions = StylePackLoadOptions(glyphsRasterizationMode: .ideographsRasterizedLocally, metadata: nil)!
        
        
        let stylePackDownload = offlineManager.loadStylePack(for: .streets, loadOptions: stylePackLoadOptions) { [weak self] progress in
            // update UI
            DispatchQueue.main.async {
                guard let progress = progress,
                      let stylePackProgressView = self?.stylePackProgressView
                else {
                    return
                }
                // Update style pack progress bar
                stylePackProgressView.progress = Float(progress.completedResourceCount)/Float(progress.requiredResourceCount)
            }
        } completion: { [ weak self] result in
            // Confirm successful download
            switch result {
            case .success(let stylePack):
                print("Style pack \(stylePack.styleURI) downloaded!")
            case .failure(let error):
                print("Error while downloading style pack: \(error).")
            }
        }

        
        // Create offline regions with tiles
        let navigationOptions = TilesetDescriptorOptions(styleURI: .streets, zoomRange: 0...10)
        let navigationDescriptor = offlineManager.createTilesetDescriptor(for: navigationOptions)
        
        // Load tile region
        let tileLoadOptions = TileLoadOptions(
            criticalPriority: false,
            acceptExpired: true,
            networkRestriction: .none)
        
        let tileRegionLoadOptions = TileRegionLoadOptions(
            geometry: MBXGeometry(coordinate: washingtonDCCoord),
            descriptors: [navigationDescriptor],
            metadata: nil,
            tileLoadOptions: tileLoadOptions,
            averageBytesPerSecond: nil)!
                
        let tileRegionDownload = tileStore.loadTileRegion(forId: dcRegionIdentifier, loadOptions: tileRegionLoadOptions) { [weak self] progress in
            // Closure gets called from the TileStore thread, so we need to dispatch to the main queue to update the UI.
            DispatchQueue.main.async {
                guard let progress = progress,
                      let tileRegionProgressView = self?.tileRegionProgressView
                else {
                    return
                }
                // Update tile region progress bar
                tileRegionProgressView.progress = Float(progress.completedResourceCount)/Float(progress.requiredResourceCount)
            }
        } completion: { [weak self] result in
            // Confirm successful download.
            switch result {
            case .success(let region):
                print("Tile \(region.id) downloaded!")
                self?.state = .downloaded
            case .failure(let error):
                print("Error while updating outdated regions: \(error).")
            }
        }
        // Wait for download to finish
//        DispatchQueue.main.async {
//            let loadingCompleted = (region.completedResourceCount == region.requiredResourceCount)
//            print("Offline region loading complete = \(loadingCompleted)")
//            if loadingCompleted {
//                self.state = .downloaded
//            }
//        }
        downloads = [tileRegionDownload]
    }
    
    func cancelDownloads() {
        downloads.forEach { $0.cancel() }
    }
    
    func showDownloadedRegions() {
        
    }

    func listOfflineRegions() -> [TileRegion] {
        var tiles: [TileRegion]
        
        tileStore.allTileRegions(completion: { result in
            do {
                tiles = try result.get()
            } catch {
                print("Error listing offline regions: \(error).")
            }
        })
        
        return tiles
    }

    // Updating a region is done by the same scenario as downloading a new one
    func refreshOutdatedOfflineRegions() {
        // refresh all existing regions
        let tiles = listOfflineRegions()
        tiles.forEach { tile in
            // TODO: ADD TILEREGIONLOADOPTIONS HERE!
            let regionLoadOptions = TileRegionLoadOptions()
            tileStore.loadTileRegion(forId: tile.id, loadOptions: <#T##TileRegionLoadOptions#>, completion: { result in
                switch result {
                case .success(let region):
                    print("Tile \(region.id) updated!")
                case .failure(let error):
                    print("Error while updating outdated regions: \(error).")
                }
            })
        }
    }

    func removeOfflineRegion(for tile: TileRegion) {
        tileStore.removeTileRegion(forId: tile.id)
    }
    
// MARK: NavigationMapView Methods
    func enableShowNavigationMapView(){
        stateButton.setTitle("Show NavigationMapView", for: .normal)
    }
        
    func showNavigationMapView() {
        progressContainer.isHidden = true
        downloadRegionsView.isHidden = true
            
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }

        view.addSubview(navigationMapView)
    }
    
// MARK: Handle State Changes
    var state: State = .beforeExampleSelected {
        didSet {
            switch(oldValue, state) {
            case(_, .initial):
             print("Example started!")
            case (.initial, .downloading):
                // Add ability to cancel download
                stateButton.setTitle("Cancel Download", for: .normal)
            case (.downloading, .downloaded):
                // Be able to display NavigationMapView
                enableShowNavigationMapView()
            case (.downloaded, .showingNavigationMapView):
                showNavigationMapView()
            case (.showingNavigationMapView, .finished):
                stateButton.setTitle("Reset", for: .normal)
            default:
                fatalError("Invalid transition from \(oldValue) to \(state).")
            }
        }
    }
    
    @objc func didTapStateButton(_ button: UIButton) {
        switch state {
        case .beforeExampleSelected:
            state = .initial
        case .initial:
            downloadOfflineRegions()
        case .downloading:
            cancelDownloads()
        case .downloaded:
            state = .showingNavigationMapView
        case .showingNavigationMapView:
            showDownloadedRegions()
        case .finished:
            state = .initial
        }
    }
}
