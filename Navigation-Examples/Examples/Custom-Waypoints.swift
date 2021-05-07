import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps
import Turf

class CustomWaypointsViewController: UIViewController {
    
    var navigationMapView: NavigationMapView!
    var navigationRouteOptions: NavigationRouteOptions!
    
    var routes: [Route]? {
        didSet {
            guard let routes = routes, let current = routes.first else {
                navigationMapView.removeRoutes()
                return
            }
            
            navigationMapView.show(routes)
            navigationMapView.showWaypoints(on: current)
        }
    }
    var startButton: UIButton!
    
    // MARK: - UIViewController lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }
        
        view.addSubview(navigationMapView)
        
        startButton = UIButton()
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
        
        requestRoute()
    }
    
    // Override layout lifecycle callback to be able to style the start button.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startButton.layer.cornerRadius = startButton.bounds.midY
        startButton.clipsToBounds = true
        startButton.setNeedsDisplay()
    }

    @objc func tappedButton(sender: UIButton) {
        guard let route = routes?.first, let navigationRouteOptions = navigationRouteOptions else { return }
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

    func requestRoute() {
        let origin = CLLocationCoordinate2DMake(37.773, -122.411)
        let firstWaypoint = CLLocationCoordinate2DMake(37.763252389415186, -122.40061448679577)
        let secondWaypoint = CLLocationCoordinate2DMake(37.76259647118012, -122.42072747880516)
        let navigationRouteOptions = NavigationRouteOptions(coordinates: [origin, firstWaypoint, secondWaypoint])
        
        let cameraOptions = CameraOptions(center: origin, zoom: 13.0)
        self.navigationMapView.mapView.camera.setCamera(to: cameraOptions)
        
        Directions.shared.calculate(navigationRouteOptions) { [weak self] (_, result) in
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
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Styling methods
    func customCircleLayer(with identifier: String, sourceIdentifier: String) -> CircleLayer {
        var circleLayer = CircleLayer(id: identifier)
        circleLayer.source = sourceIdentifier
        let opacity = Exp(.switchCase) {
            Exp(.any) {
                Exp(.get) {
                    "waypointCompleted"
                }
            }
            0.5
            1
        }
        circleLayer.paint?.circleColor = .constant(.init(color: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)))
        circleLayer.paint?.circleOpacity = .expression(opacity)
        circleLayer.paint?.circleRadius = .constant(.init(10))
        circleLayer.paint?.circleStrokeColor = .constant(.init(color: UIColor.black))
        circleLayer.paint?.circleStrokeWidth = .constant(.init(1))
        circleLayer.paint?.circleStrokeOpacity = .expression(opacity)
        return circleLayer
    }

    func customSymbolLayer(with identifier: String, sourceIdentifier: String) -> SymbolLayer {
        var symbolLayer = SymbolLayer(id: identifier)
        symbolLayer.source = sourceIdentifier
        symbolLayer.layout?.textField = .expression(Exp(.toString) {
            Exp(.get) {
                "name"
            }
        })
        symbolLayer.layout?.textSize = .constant(.init(10))
        symbolLayer.paint?.textOpacity = .expression(Exp(.switchCase) {
            Exp(.any) {
                Exp(.get) {
                    "waypointCompleted"
                }
            }
            0.5
            1
        })
        symbolLayer.paint?.textHaloWidth = .constant(.init(0.25))
        symbolLayer.paint?.textHaloColor = .constant(.init(color: UIColor.black))
        return symbolLayer
    }

    func customWaypointShape(shapeFor waypoints: [Waypoint], legIndex: Int) -> FeatureCollection {
        var features = [Feature]()
        for (waypointIndex, waypoint) in waypoints.enumerated() {
            var feature = Feature(Point(waypoint.coordinate))
            feature.properties = [
                "waypointCompleted": waypointIndex < legIndex,
                "name": "#\(waypointIndex + 1)"
            ]
            features.append(feature)
        }
        return FeatureCollection(features: features)
    }
}

// MARK: Delegate methods
extension CustomWaypointsViewController: NavigationMapViewDelegate {
    func navigationMapView(_ navigationMapView: NavigationMapView, waypointCircleLayerWithIdentifier identifier: String, sourceIdentifier: String) -> CircleLayer? {
        return customCircleLayer(with: identifier, sourceIdentifier: sourceIdentifier)
    }

    func navigationMapView(_ navigationMapView: NavigationMapView, waypointSymbolLayerWithIdentifier identifier: String, sourceIdentifier: String) -> SymbolLayer? {
        return customSymbolLayer(with: identifier, sourceIdentifier: sourceIdentifier)
    }

    func navigationMapView(_ navigationMapView: NavigationMapView, shapeFor waypoints: [Waypoint], legIndex: Int) -> FeatureCollection? {
        return customWaypointShape(shapeFor: waypoints, legIndex: legIndex)
    }
}

extension CustomWaypointsViewController: NavigationViewControllerDelegate {
    func navigationViewController(_ navigationViewController: NavigationViewController, waypointCircleLayerWithIdentifier identifier: String, sourceIdentifier: String) -> CircleLayer? {
        return customCircleLayer(with: identifier, sourceIdentifier: sourceIdentifier)
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, waypointSymbolLayerWithIdentifier identifier: String, sourceIdentifier: String) -> SymbolLayer? {
        return customSymbolLayer(with: identifier, sourceIdentifier: sourceIdentifier)
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, shapeFor waypoints: [Waypoint], legIndex: Int) -> FeatureCollection? {
        return customWaypointShape(shapeFor: waypoints, legIndex: legIndex)
    }
}
