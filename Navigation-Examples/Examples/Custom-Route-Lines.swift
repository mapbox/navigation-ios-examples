import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps
import Turf

class CustomRouteLinesViewController: UIViewController {
    
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
    
    // MARK: - UIViewController lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationMapView()
        setupPerformActionBarButtonItem()
        setupGestureRecognizers()
    }
    
    // MARK: - Setting-up methods
    
    func setupNavigationMapView() {
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }
        
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource

        view.addSubview(navigationMapView)
    }
    
    func setupPerformActionBarButtonItem() {
        let settingsBarButtonItem = UIBarButtonItem(title: NSString(string: "\u{2699}\u{0000FE0E}") as String,
                                                    style: .plain,
                                                    target: self,
                                                    action: #selector(performAction))
        settingsBarButtonItem.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 30)], for: .normal)
        settingsBarButtonItem.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 30)], for: .highlighted)
        navigationItem.rightBarButtonItem = settingsBarButtonItem
    }
    
    @objc func performAction(_ sender: Any) {
        let alertController = UIAlertController(title: "Perform action",
                                                message: "Select specific action to perform it", preferredStyle: .actionSheet)
        
        typealias ActionHandler = (UIAlertAction) -> Void
        
        let startNavigation: ActionHandler = { _ in self.startNavigation() }
        let removeRoutes: ActionHandler = { _ in self.routes = nil }
        
        let actions: [(String, UIAlertAction.Style, ActionHandler?)] = [
            ("Start Navigation", .default, startNavigation),
            ("Remove Routes", .default, removeRoutes),
            ("Cancel", .cancel, nil)
        ]
        
        actions
            .map({ payload in UIAlertAction(title: payload.0, style: payload.1, handler: payload.2) })
            .forEach(alertController.addAction(_:))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alertController, animated: true, completion: nil)
    }

    func setupGestureRecognizers() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        navigationMapView.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    @objc func startNavigation() {
        guard let route = currentRoute else {
            print("Please select at least one destination coordinate to start navigation.")
            return
        }
        
        let navigationService = MapboxNavigationService(route: route,
                                                        routeIndex: 0,
                                                        routeOptions: navigationRouteOptions,
                                                        simulating: simulationIsEnabled ? .always : .onPoorGPS)
        
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        let navigationViewController = NavigationViewController(for: route,
                                                                routeIndex: 0,
                                                                routeOptions: navigationRouteOptions,
                                                                navigationOptions: navigationOptions)
        navigationViewController.delegate = self
        navigationViewController.modalPresentationStyle = .fullScreen
        
        navigationViewController.routeLineTracksTraversal = true

        present(navigationViewController, animated: true, completion: nil)
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        createWaypoints(for: navigationMapView.mapView.coordinate(for: gesture.location(in: navigationMapView.mapView)))
        requestRoute()
    }

    func createWaypoints(for destinationCoordinate: CLLocationCoordinate2D?) {
        guard let destinationCoordinate = destinationCoordinate else { return }
        guard let userLocation = navigationMapView.mapView.locationManager.latestLocation?.internalLocation else {
            print("User location is not valid. Make sure to enable Location Services.")
            return
        }
        
        let cameraOptions = CameraOptions(center: origin, zoom: 13.0)
        self.navigationMapView.mapView.camera.setCamera(to: cameraOptions)
        
        // Add destination waypoint to list of waypoints.
        let waypoint = Waypoint(coordinate: destinationCoordinate)
        waypoint.targetCoordinate = destinationCoordinate
        waypoints.append(waypoint)
    }

    func requestRoute() {
        let navigationRouteOptions = NavigationRouteOptions(waypoints: waypoints)
        Directions.shared.calculate(navigationRouteOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print("Error occured while requesting route: \(error.localizedDescription).")

                // In case if direction calculation failed - remove last destination waypoint.
                self?.waypoints.removeLast()
            case .success(let response):
                guard let routes = response.routes else { return }
                self?.navigationRouteOptions = navigationRouteOptions
                self?.routes = routes
                self?.navigationMapView.show(routes)
                if let currentRoute = self?.currentRoute {
                    self?.navigationMapView.showWaypoints(on: currentRoute)
                }

                if let coordinates = self?.waypoints.compactMap({ $0.targetCoordinate }) {
                    self?.navigationMapView.highlightBuildings(at: coordinates, in3D: true)
                }
            }
        }
    }
}

// MARK: - NavigationMapViewDelegate methods

extension CustomRouteLinesViewController: NavigationMapViewDelegate {
    
    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        self.currentRoute = route
    }
    
    func navigationMapView(_ navigationMapView: NavigationMapView, shapeFor route: Route) -> LineString? {
        return route.shape
    }
    
    func navigationMapView(_ navigationMapView: NavigationMapView, casingShapeFor route: Route) -> LineString? {
        return route.shape
    }
    
    func navigationMapView(_ navigationMapView: NavigationMapView, routeLineLayerWithIdentifier identifier: String, sourceIdentifier: String) -> LineLayer? {
        var lineLayer = LineLayer(id: identifier)
        lineLayer.source = sourceIdentifier
        lineLayer.paint?.lineColor = .constant(.init(color: .red))
        lineLayer.paint?.lineWidth = .constant(10.0)
        lineLayer.layout?.lineJoin = .constant(.round)
        lineLayer.layout?.lineCap = .constant(.round)
        
        return lineLayer
    }
    
    func navigationMapView(_ navigationMapView: NavigationMapView, routeCasingLineLayerWithIdentifier identifier: String, sourceIdentifier: String) -> LineLayer? {
        var lineLayer = LineLayer(id: identifier)
        lineLayer.source = sourceIdentifier
        lineLayer.paint?.lineColor = .constant(.init(color: .green))
        lineLayer.paint?.lineWidth = .constant(14.0)
        lineLayer.layout?.lineJoin = .constant(.round)
        lineLayer.layout?.lineCap = .constant(.round)
        
        return lineLayer
    }
}

// MARK: - NavigationViewControllerDelegate methods

extension CustomRouteLinesViewController: NavigationViewControllerDelegate {
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        dismiss(animated: true, completion: nil)
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, routeLineLayerWithIdentifier identifier: String, sourceIdentifier: String) -> LineLayer? {
        var lineLayer = LineLayer(id: identifier)
        lineLayer.source = sourceIdentifier
        lineLayer.paint?.lineColor = .constant(.init(color: .red))
        lineLayer.paint?.lineWidth = .constant(10.0)
        lineLayer.layout?.lineJoin = .constant(.round)
        lineLayer.layout?.lineCap = .constant(.round)
        
        return lineLayer
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, routeCasingLineLayerWithIdentifier identifier: String, sourceIdentifier: String) -> LineLayer? {
        var lineLayer = LineLayer(id: identifier)
        lineLayer.source = sourceIdentifier
        lineLayer.paint?.lineColor = .constant(.init(color: .green))
        lineLayer.paint?.lineWidth = .constant(14.0)
        lineLayer.layout?.lineJoin = .constant(.round)
        lineLayer.layout?.lineCap = .constant(.round)
        
        return lineLayer
    }
}
