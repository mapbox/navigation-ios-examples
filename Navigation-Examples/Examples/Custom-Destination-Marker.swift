import Foundation
import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

class CustomDestinationMarkerController: UIViewController {
    
    var navigationMapView: NavigationMapView!
    var navigationRouteOptions: NavigationRouteOptions!
    var startNavigationButton: UIButton!
    var routes: [Route] = []
    
    // MARK: - UIViewController lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationMapView()
        setupStartNavigationButton()
        requestRoute()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startNavigationButton.layer.cornerRadius = startNavigationButton.bounds.midY
        startNavigationButton.clipsToBounds = true
        startNavigationButton.setNeedsDisplay()
    }
    
    // MARK: - Setting-up methods
    
    func setupNavigationMapView() {
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }
        
        view.addSubview(navigationMapView)
    }
    
    func setupStartNavigationButton() {
        startNavigationButton = UIButton()
        startNavigationButton.setTitle("Start Navigation", for: .normal)
        startNavigationButton.translatesAutoresizingMaskIntoConstraints = false
        startNavigationButton.backgroundColor = .white
        startNavigationButton.setTitleColor(.black, for: .highlighted)
        startNavigationButton.setTitleColor(.darkGray, for: .normal)
        startNavigationButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startNavigationButton.addTarget(self, action: #selector(tappedButton(_:)), for: .touchUpInside)
        startNavigationButton.isHidden = true
        view.addSubview(startNavigationButton)
        
        startNavigationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startNavigationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
    
    @objc func tappedButton(_ sender: UIButton) {
        guard let route = routes.first, let routeOptions = navigationRouteOptions else { return }
        let navigationService = MapboxNavigationService(route: route,
                                                        routeIndex: 0,
                                                        routeOptions: routeOptions,
                                                        simulating: simulationIsEnabled ? .always : .onPoorGPS)
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        let navigationViewController = NavigationViewController(for: route,
                                                                routeIndex: 0,
                                                                routeOptions: routeOptions,
                                                                navigationOptions: navigationOptions)
        navigationViewController.modalPresentationStyle = .fullScreen
        navigationViewController.delegate = self
        
        present(navigationViewController, animated: true)
    }
    
    func requestRoute() {
        let origin = CLLocationCoordinate2DMake(37.77440680146262, -122.43539772352648)
        let destination = CLLocationCoordinate2DMake(37.76556957793795, -122.42409811526268)
        let navigationRouteOptions = NavigationRouteOptions(coordinates: [origin, destination])
        
        navigationMapView.mapView.camera.setCamera(to: CameraOptions(center: destination, zoom: 13.0))
        
        Directions.shared.calculate(navigationRouteOptions) { [weak self] (_, result) in
            switch result {
            case .failure(let error):
                NSLog("Error occured: \(error.localizedDescription).")
            case .success(let response):
                guard let routes = response.routes,
                      let currentRoute = routes.first,
                      let self = self else { return }
                
                self.navigationRouteOptions = navigationRouteOptions
                self.routes = routes
                self.startNavigationButton?.isHidden = false
                
                self.navigationMapView.show(routes)
                self.navigationMapView.showWaypoints(on: currentRoute)
            }
        }
    }
}

// MARK: - NavigationMapViewDelegate methods

extension CustomDestinationMarkerController: NavigationMapViewDelegate {
    
    func navigationMapView(_ navigationMapView: NavigationMapView, didAdd finalDestinationAnnotation: PointAnnotation) {
        var finalDestinationAnnotation = finalDestinationAnnotation
        finalDestinationAnnotation.image = UIImage(named: "marker")
        
        do {
            try navigationMapView.mapView.annotations.updateAnnotation(finalDestinationAnnotation)
        } catch {
            NSLog("Error occured: \(error.localizedDescription).")
        }
    }
}

// MARK: - NavigationViewControllerDelegate methods

extension CustomDestinationMarkerController: NavigationViewControllerDelegate {
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didAdd finalDestinationAnnotation: PointAnnotation) {
        var finalDestinationAnnotation = finalDestinationAnnotation
        finalDestinationAnnotation.image = UIImage(named: "marker")
        
        do {
            try navigationViewController.navigationMapView?.mapView.annotations.updateAnnotation(finalDestinationAnnotation)
        } catch {
            NSLog("Error occured: \(error.localizedDescription).")
        }
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        dismiss(animated: true)
    }
}
