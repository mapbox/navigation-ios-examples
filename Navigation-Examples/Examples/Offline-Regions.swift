import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

class OfflineRegionsViewController: UIViewController, NavigationViewControllerDelegate {

    var tileStore: TileStore!
    var resourceOptions: ResourceOptions!
    
    // Transition button, progress view
    var stateButton: UIButton!
//    var tileRegionsTableView: UITableView!
    var stylePackProgressView: UIProgressView!
    var tileRegionProgressView: UIProgressView!
    var downloadRegionsView: UIView!
    
    var startButton: UIButton!
    var navigationMapView: NavigationMapView!
    var navigationRouteOptions: NavigationRouteOptions!
    
    var currentRoute: Route? {
        get {
            return routes?.first
        }
        set {
            guard let selected = newValue else { routes = nil; return }
            guard let routes = routes else { self.routes = [selected]; return }
            self.routes = [selected] + routes.filter { $0 != selected }
        }
    }
    
    var routes: [Route]? {
        didSet {
            guard let routes = routes, let currentRoute = routes.first else {
                navigationMapView.removeRoutes()
                navigationMapView.removeWaypoints()
                waypoints.removeAll()
                return
            }

            navigationMapView.show(routes)
            navigationMapView.showWaypoints(on: currentRoute)
        }
    }
    
    var waypoints: [Waypoint] = []
    
    // Tile region and style pack
    var downloads: [Cancelable] = []
    
    // Create some hard-coded regions
    let tileZoom: CGFloat = 12
    let tileAreas: [ToBeTileRegion] = [
        ToBeTileRegion(coordinates: CLLocationCoordinate2D(latitude: 38.907, longitude: -77.036), identifier: "Washington DC Tile Region"),
        ToBeTileRegion(coordinates: CLLocationCoordinate2D(latitude: 39.289, longitude: -76.613), identifier: "Baltimore Tile Region"),
        ToBeTileRegion(coordinates: CLLocationCoordinate2D(latitude: 38.805, longitude: -77.046), identifier: "Alexandria Tile Region")
    ]
    let washingtonDCCoord = CLLocationCoordinate2D(latitude: 38.907, longitude: -77.036)
    let dcRegionIdentifier = "Washington DC Tile Region"
    
    var offlineManager: OfflineManager!
    var mapInitOptions: MapInitOptions!
    
    struct ToBeTileRegion {
        var coordinates: CLLocationCoordinate2D
        var identifier: String
    }
    
    enum State {
        case beforeExampleSelected
        case initial
//        case downloading
        case downloaded
        case finished
        case showingNavigationMapView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialSetup()
        state = .initial
    }
    
    func initialSetup() {
        resourceOptions = createCustomTileStore()
        offlineManager = OfflineManager(resourceOptions: resourceOptions)
        mapInitOptions = MapInitOptions(resourceOptions: resourceOptions, cameraOptions: CameraOptions(center: washingtonDCCoord, zoom: tileZoom), styleURI: .streets)
        
        downloadRegionsView = UIView(frame: self.view.bounds)
        downloadRegionsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(downloadRegionsView)
        downloadRegionsView.backgroundColor = UIColor.white
        
        setupStateButton()
        setupProgressViews()
    }
    
    func setupStateButton() {
        stateButton = UIButton()
        stateButton.setTitle("Start Downloads", for: .normal)
        stateButton.translatesAutoresizingMaskIntoConstraints = false
        stateButton.backgroundColor = .blue
        stateButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        stateButton.isHidden = false
        stateButton.addTarget(self, action: #selector(didTapStateButton(_:)), for: .touchUpInside)
        view.addSubview(stateButton)
        
        stateButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        stateButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
    
    func setupStartButton() {
        startButton = UIButton()
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.backgroundColor = .blue
        startButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startButton.addTarget(self, action: #selector(tappedStartButton(_:)), for: .touchUpInside)
        startButton.isHidden = true
        view.addSubview(startButton)
        
        startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
    
    func setupProgressViews() {
        stylePackProgressView = UIProgressView(frame: CGRect(x: 10, y: 200, width: view.frame.size.width-20, height: 20))
        let stylePackProgressLabel = UILabel(frame: CGRect(x: 10, y: 150, width: view.frame.size.width-20, height: 20))
        stylePackProgressLabel.bottomAnchor.constraint(equalTo: self.stylePackProgressView.topAnchor)
        stylePackProgressLabel.text = "Style Pack"
        view.addSubview(stylePackProgressView)
        view.addSubview(stylePackProgressLabel)
        stylePackProgressView.progress = 0.0
        
        tileRegionProgressView = UIProgressView(frame: CGRect(x: 10, y: 300, width: view.frame.size.width-20, height: 20))
        let tileRegionProgressLabel = UILabel(frame: CGRect(x: 10, y: 250, width: view.frame.size.width-20, height: 20))
        tileRegionProgressLabel.bottomAnchor.constraint(equalTo: self.tileRegionProgressView.topAnchor)
        tileRegionProgressLabel.text = "Tile Region"
        view.addSubview(tileRegionProgressView)
        view.addSubview(tileRegionProgressLabel)
        tileRegionProgressView.progress = 0.0
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
    
//    func setupTileRegionsTableView() {
//        tileRegionsTableView = UITableView()
//    }
//
// MARK: Offline Regions
    @objc func updateRegions(_ sender: Any) {
        refreshOutdatedOfflineRegions()
    }
    
//    @objc func listRegions(_ sender: Any) {
//        tileRegionsTableView.isHidden = false
//    }

    func createCustomTileStore() -> ResourceOptions {
        // get access token
        guard let accessToken = CredentialsManager.default.accessToken else {
            fatalError("Access token was not set.")
        }

        // Create a TileStore instance at the default location
        tileStore = TileStore.getInstance()
        return ResourceOptions(accessToken: accessToken,
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
        } completion: { result in
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
//                self?.state = .downloading
            }
        } completion: { result in
            // Confirm successful download.
            switch result {
            case .success(let region):
                print("Tile \(region.id) downloaded!")
            case .failure(let error):
                print("Error while updating outdated regions: \(error).")
            }
        }
        downloads = [stylePackDownload, tileRegionDownload]
        self.state = .downloaded
    }
    
//    func cancelDownloads() {
//        downloads.forEach { $0.cancel() }
//    }
    
    func showDownloadedRegions() {
        
    }

    func listOfflineRegions() -> [TileRegion] {
        var tiles: [TileRegion] = []
        
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
        let tileLoadOptions = TileLoadOptions(
            criticalPriority: false,
            acceptExpired: true,
            networkRestriction: .none)
        
        tiles.forEach { tile in
            let tileRegionLoadOptions = TileRegionLoadOptions(
                geometry: MBXGeometry(coordinate: washingtonDCCoord),
                tileLoadOptions: tileLoadOptions)!
            
            tileStore.loadTileRegion(forId: tile.id, loadOptions: tileRegionLoadOptions, completion: { result in
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
        return
    }
        
    func showNavigationMapView() {
        downloadRegionsView.isHidden = true
            
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }

        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false
        navigationViewportDataSource.followingMobileCamera.zoom = 12.0
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        view.addSubview(navigationMapView)
    }
    @objc func tappedStartButton(_ button: UIButton) {
        guard let route = currentRoute, let navigationRouteOptions = navigationRouteOptions else { return }
        // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
        let navigationService = MapboxNavigationService(route: route,
                                                        routeIndex: 0,
                                                        routeOptions: navigationRouteOptions,
                                                        simulating: simulationIsEnabled ? .always : .onPoorGPS)
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        let navigationViewController = NavigationViewController(for: route, routeIndex: 0,
                                                                routeOptions: navigationRouteOptions,
                                                                navigationOptions: navigationOptions)
        navigationViewController.delegate = self
        
        present(navigationViewController, animated: true, completion: nil)
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = navigationMapView.mapView.mapboxMap.coordinate(for: gesture.location(in: navigationMapView.mapView))
        
        requestRoute(destination: location)
    }
    
    func requestRoute(destination: CLLocationCoordinate2D) {
        guard let userLocation = navigationMapView.mapView.location.latestLocation else { return }
        let userWaypoint = Waypoint(location: userLocation.internalLocation, heading: userLocation.heading, name: "user")
        let destinationWaypoint = Waypoint(coordinate: destination)
        let navigationRouteOptions = NavigationRouteOptions(waypoints: [userWaypoint, destinationWaypoint])
        
        Directions.shared.calculate(navigationRouteOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let routes = response.routes,
                      let currentRoute = routes.first,
                      let self = self else { return }
                
                self.navigationRouteOptions = navigationRouteOptions
                self.routes = routes
                self.startButton?.isHidden = false
                self.navigationMapView.show(routes)
                self.navigationMapView.showWaypoints(on: currentRoute)
            }
        }
    }
    
    
// MARK: Handle State Changes
    var state: State = .beforeExampleSelected {
        didSet {
            switch(oldValue, state) {
            case(_, .initial):
             print("Example started!")
//            case (.initial, .downloading):
//                // Add ability to cancel download
//                print()
//                stateButton.setTitle("Cancel Download", for: .normal)
//            case (.downloading, .downloaded):
//                // Be able to display NavigationMapView
//                enableShowNavigationMapView()
            case (.initial, .downloaded):
                // Add ability to cancel download
                print()
                enableShowNavigationMapView()
            case (.downloaded, .showingNavigationMapView):
                showNavigationMapView()
            case (.showingNavigationMapView, .finished):
                print()
//                stateButton.setTitle("Reset", for: .normal)
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
            print("!!! INITIAL STATE")
            downloadOfflineRegions()
//        case .downloading:
//            cancelDownloads()
//            state = .downloaded
        case .downloaded:
            print("!!! DOWNLOADED STATE")
            state = .showingNavigationMapView
        case .showingNavigationMapView:
            showDownloadedRegions()
        case .finished:
            state = .initial
        }
    }
}
