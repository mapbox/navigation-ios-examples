// #-code-snippet: navigation dependencies-swift
import MapboxMaps
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import Turf
// #-end-code-snippet: navigation dependencies-swift

class ViewController: UIViewController {
    // #-code-snippet: navigation vc-variables-swift
    var navigationMapView: NavigationMapView!
    var navigationViewController: NavigationViewController!
    var routeOptions: NavigationRouteOptions?
    var route: Route?
    var startButton: UIButton!
    // #-end-code-snippet: navigation vc-variables-swift

    // #-code-snippet: navigation view-did-load-swift
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigationMapView)

        // Allow the map to display the user's location
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }
        
        // By default `NavigationViewportDataSource` tracks location changes from `PassiveLocationDataSource`, to consume
        // raw locations `ViewportDataSourceType` should be set to `.raw`.
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        // Add a gesture recognizer to the map view
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        navigationMapView.addGestureRecognizer(longPress)
        
        // Add a button to start navigation
        displayStartButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startButton.layer.cornerRadius = startButton.bounds.midY
        startButton.clipsToBounds = true
        startButton.setNeedsDisplay()
    }
    // #-end-code-snippet: navigation view-did-load-swift
    
    // #-code-snippet: navigation display-start-button-swift
    func displayStartButton() {
        startButton = UIButton()
        
        // Add a title and set the button's constraints
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.backgroundColor = .blue
        startButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startButton.addTarget(self, action: #selector(tappedButton(sender:)), for: .touchUpInside)
        startButton.isHidden = true
        view.addSubview(startButton)
        
        startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
    // #-end-code-snippet: navigation display-start-button-swift
    
    // #-code-snippet: navigation long-press-swift
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }

        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: navigationMapView)
        let coordinate = navigationMapView.mapView.coordinate(for: point)

        if let origin = navigationMapView.mapView.location.latestLocation?.internalLocation.coordinate {
            // Calculate the route from the user's location to the set destination
            calculateRoute(from: origin, to: coordinate)
        } else {
            print("Failed to get user location, make sure to allow location access for this application.")
        }
    }
    // #-end-code-snippet: navigation long-press-swift
    
    // #-code-snippet: navigation tapped-button-swift
    // Present the navigation view controller when the start button is tapped
    @objc func tappedButton(sender: UIButton) {
        guard let route = route, let navigationRouteOptions = routeOptions else { return }
        
        navigationViewController = NavigationViewController(for: route, routeIndex: 0,
                                                                routeOptions: navigationRouteOptions)
        navigationViewController.modalPresentationStyle = .fullScreen
        
        present(navigationViewController, animated: true, completion: nil)
    }
    // #-end-code-snippet: navigation tapped-button-swift

    // #-code-snippet: navigation calculate-route-swift
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        // Coordinate accuracy is how close the route must come to the waypoint in order to be considered viable. It is measured in meters. A negative value indicates that the route is viable regardless of how far the route is from the waypoint.
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")

        // Specify that the route is intended for automobiles avoiding traffic
        let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)

        // Generate the route object and draw it on the map
        Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                strongSelf.route = route
                strongSelf.routeOptions = routeOptions
                
                // Show the start button
                strongSelf.startButton?.isHidden = false
                
                // Draw the route on the map after creating it
                strongSelf.drawRoute(route: route)
                
                // Show destination waypoint on the map
                strongSelf.navigationMapView.showWaypoints(on: route)
            }
        }
    }
    // #-end-code-snippet: navigation calculate-route-swift

    // #-code-snippet: navigation draw-route-swift
    func drawRoute(route: Route) {
        guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
        guard let mapView = navigationMapView.mapView else { return }
        let sourceIdentifier = "routeStyle"
        
        // Convert the route’s coordinates into a linestring feature
        let feature = Feature(LineString(routeShape.coordinates))
        
        // If there's already a route line on the map, update its shape to the new route
        if let _ = try? mapView.style.getSource(identifier: sourceIdentifier, type: GeoJSONSource.self).get() {
            let _ = mapView.style.updateGeoJSON(for: sourceIdentifier, with: feature)
        } else {
            // Convert the route’s coordinates into a lineString Feature and add the source of the route line to the map
            var geoJSONSource = GeoJSONSource()
            geoJSONSource.data = .feature(feature)
            mapView.style.addSource(source: geoJSONSource, identifier: sourceIdentifier)
            
            // Customize the route line color and width
            var lineLayer = LineLayer(id: "routeLayer")
            lineLayer.source = sourceIdentifier
            lineLayer.paint?.lineColor = .constant(.init(color: UIColor(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1.0)))
            lineLayer.paint?.lineWidth = .constant(3)
            
            // Add the style layer of the route line to the map
            mapView.style?.addLayer(layer: lineLayer)
        }
    }
    // #-end-code-snippet: navigation draw-route-swift
}
