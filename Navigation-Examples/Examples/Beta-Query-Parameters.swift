import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

class BetaQueryViewController: UIViewController, NavigationMapViewDelegate, NavigationViewControllerDelegate {
    
    var navigationMapView: NavigationMapView!
    var navigationRouteOptions: MopedRouteOptions!
    //        let options = MopedRouteOptions(coordinates: [origin, destination], profileIdentifier: .automobile)
    
    var routes: [Route]? {
        didSet {
            guard let routes = routes, let current = routes.first else {
                navigationMapView.removeRoutes();
                return
            }
            
            navigationMapView.show(routes)
            navigationMapView.showWaypoints(on: current)
        }
    }
    
    var startButton: UIButton!
    var datePicker: UIDatePicker!
    var dateTextField: UITextField!
    var departureTime: Date!
    
    // MARK: - UIViewController lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        navigationMapView.mapView.update {
            $0.location.puckType = .puck2D()
        }
        
        // TODO: Provide a reliable way of setting camera to current coordinate.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let coordinate = self.navigationMapView.mapView.location.latestLocation?.coordinate {
                let cameraOptions = CameraOptions(center: coordinate, zoom: 13.0)
                self.navigationMapView.mapView.camera.setCamera(to: cameraOptions)
            }
        }
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        navigationMapView.addGestureRecognizer(gesture)
        
        view.addSubview(navigationMapView)

        startButton = UIButton()
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.backgroundColor = .blue
        startButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startButton.addTarget(self, action: #selector(tappedStartButton(sender:)), for: .touchUpInside)
        startButton.isHidden = true
        view.addSubview(startButton)
        
        startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
        
        dateTextField = UITextField(frame: CGRect(x: 75, y: 100, width: 200, height: 35))
        dateTextField.placeholder = "Enter departure time"
        dateTextField.backgroundColor = UIColor.white
        dateTextField.borderStyle = .roundedRect
        dateTextField.center.x = view.center.x
        dateTextField.isHidden = false
        showDatePicker()
        view.addSubview(dateTextField)
//        view.addSubview(datePicker)
    }
    
    // Override layout lifecycle callback to be able to style the start button.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startButton.layer.cornerRadius = startButton.bounds.midY
        startButton.clipsToBounds = true
        startButton.setNeedsDisplay()
    }

    func showDatePicker() {
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .time
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
//        datePicker.addTarget(self, action: nil, for: nil)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(doneButtonPressed))
        toolbar.setItems([doneButton], animated: true)

        dateTextField?.inputAccessoryView = toolbar
        dateTextField?.inputView = datePicker
    }
    
    @objc func doneButtonPressed() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm" // format date correctly
        dateTextField.text = dateFormatter.string(from: datePicker.date)
        NotificationCenter.default.post(name: .didSetDepartureTime, object: nil, userInfo: ["departureTime": dateTextField.text!])
        self.view.endEditing(true)
    }
    
    @objc func tappedStartButton(sender: UIButton) {
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
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = navigationMapView.mapView.coordinate(for: gesture.location(in: navigationMapView.mapView))
        
        requestRoute(destination: location)
    }

    func requestRoute(destination: CLLocationCoordinate2D) {
        guard let userLocation = navigationMapView.mapView.location.latestLocation else { return }
        let userWaypoint = Waypoint(location: userLocation.internalLocation, heading: userLocation.heading, name: "user")
        let destinationWaypoint = Waypoint(coordinate: destination)
        let navigationRouteOptions = MopedRouteOptions(waypoints: [userWaypoint, destinationWaypoint])
        print("!!! navigationRouteOptions: \(navigationRouteOptions)")
        
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
                self.dateTextField?.isHidden = true
                self.navigationMapView.show(routes)
                self.navigationMapView.showWaypoints(on: currentRoute)
            }
        }
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        dismiss(animated: true, completion: nil)
    }
}

extension Notification.Name {
    static let didSetDepartureTime: Notification.Name = .init(rawValue: "didSetDepartureTime")
}

class MopedRouteOptions: NavigationRouteOptions {
    var departureTime: String! {
        didSet {
            observeNotification()
        }
    }
    
    override var urlQueryItems: [URLQueryItem] {
//        let maximumSpeed = Measurement(value: 30, unit: UnitSpeed.milesPerHour)
        
//        let hourFromNow = Date().addingTimeInterval(60 * 60) // an hour from now
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm" // format date correctly
//        let hourFromNowString = dateFormatter.string(from: hourFromNow)
        // URLQueryItem(name: "maxspeed", value: String(maximumSpeed.converted(to: .kilometersPerHour).value)),
        let items = [URLQueryItem(name: "depart_at", value: departureTime)]
        print("!!! departure time: \(String(describing: departureTime))")
        if let queryItems = super.urlQueryItems as [URLQueryItem]? {
            print("!!! queryItems: \(queryItems)")
            print()
            print("!!! queryItems + items: \(queryItems + items)")
            return queryItems + items
        }
    }
    
    func observeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(getDepartureTime), name: .didSetDepartureTime, object: nil)
    }
    
    @objc func getDepartureTime(_ notification: Notification) {
        if let departTime = notification.userInfo?["departureTime"] as? String {
            departureTime = departTime
        }
    }
}

