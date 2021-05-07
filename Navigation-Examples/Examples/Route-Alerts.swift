import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxNavigationNative

class RouteAlertsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let origin = CLLocationCoordinate2DMake(37.789811651648456, -122.47075850058)
        let destination = CLLocationCoordinate2DMake(37.79727245401114, -122.46951395567203)
        let options = NavigationRouteOptions(coordinates: [origin, destination])
        
        Directions.shared.calculate(options) { [weak self] (_, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
                let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options, simulating: simulationIsEnabled ? .always : .onPoorGPS)
                
                // Define a customized `topBanner` to display route alerts during turn-by-turn navigation, and pass it to `NavigationOptions`.
                let topAlertsBannerViewController = TopAlertsBarViewController()
                let navigationOptions = NavigationOptions(navigationService: navigationService, topBanner: topAlertsBannerViewController)
                let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)

                let parentSafeArea = navigationViewController.view.safeAreaLayoutGuide
                topAlertsBannerViewController.view.topAnchor.constraint(equalTo: parentSafeArea.topAnchor).isActive = true
                
                navigationViewController.modalPresentationStyle = .fullScreen
                
                strongSelf.present(navigationViewController, animated: true)
            }
        }
    }
}

// MARK: - TopAlertsBarViewController
class TopAlertsBarViewController: ContainerViewController {
    
    lazy var topAlertsBannerView: InstructionsBannerView = {
        let banner = InstructionsBannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 25
        banner.layer.opacity = 0.8
        return banner
    }()
    
    override func viewDidLoad() {
        view.addSubview(topAlertsBannerView)
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupConstraints()
    }
    
    private func setupConstraints() {
        
        // To change top banner size and position change layout constraints directly.
        let topAlertsBannerViewConstraints: [NSLayoutConstraint] = [
            topAlertsBannerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            topAlertsBannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            topAlertsBannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            topAlertsBannerView.heightAnchor.constraint(equalToConstant: 100.0),
            topAlertsBannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ]
        NSLayoutConstraint.activate(topAlertsBannerViewConstraints)
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setupConstraints()
    }
    
    public func updateAlerts(alerts: [String]) {
        
        // Change the property of`primaryLabel: InstructionLabel`.
        let text = alerts.joined(separator: "\n")
        topAlertsBannerView.primaryLabel.text = text
        topAlertsBannerView.primaryLabel.numberOfLines = 0
        topAlertsBannerView.primaryLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
    }
    
    // MARK: - NavigationServiceDelegate implementation
    
    public func navigationService(_ service: NavigationService, didPassVisualInstructionPoint instruction: VisualInstructionBanner, routeProgress: RouteProgress) {
        topAlertsBannerView.update(for: instruction)
    }
    
    public func navigationService(_ service: NavigationService, didRerouteAlong route: Route, at location: CLLocation?, proactive: Bool) {
        topAlertsBannerView.updateDistance(for: service.routeProgress.currentLegProgress.currentStepProgress)
    }
    
    public func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        topAlertsBannerView.updateDistance(for: service.routeProgress.currentLegProgress.currentStepProgress)
        let allAlerts = progress.upcomingRouteAlerts.filter({ !$0.description.isEmpty }).map({ $0.description })
        if !allAlerts.isEmpty {
            updateAlerts(alerts: allAlerts)
        } else {
            // If there's no usable route alerts in the route progress, displaying `currentVisualInstruction` instead.
            let instruction = progress.currentLegProgress.currentStepProgress.currentVisualInstruction
            topAlertsBannerView.primaryLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
            topAlertsBannerView.update(for: instruction)
        }
    }
}

// MARK: - MapboxCoreNavigation.RouteAlert to String implementation
extension MapboxDirections.Incident: CustomStringConvertible {
    
    public var alertDescription: String {
        guard let kind = self.kind else { return self.description }
        if let impact = self.impact, let lanesBlocked = self.lanesBlocked {
            return "A \(impact) \(kind) ahead blocking \(lanesBlocked)"
        } else if let impact = self.impact {
            return "A \(impact) \(kind) ahead"
        } else {
            return "A \(kind) ahead blocking \(self.lanesBlocked!)"
        }
    }
}

extension MapboxCoreNavigation.RouteAlert: CustomStringConvertible {
    
    public var description: String {
        let distance = Int64(self.distanceToStart)
        guard distance > 0 && distance < 500 else { return "" }
        
        let alertInfo = self.alert
        switch alertInfo {
        case .incident(let incident):
            return "\(incident.alertDescription) in \(distance)m."
        case .tunnel(let alert):
            if let alertName = alert.name {
                return "Tunnel \(alertName) in \(distance)m."
            } else {
                return "A tunnel in \(distance)m."
            }
        case .borderCrossing(let alert):
            return "Crossing border from \(alert.from) to \(alert.to) in \(distance)m."
        case .serviceArea(let alert):
            switch alert.type {
            case .restArea:
                return "Rest area in \(distance)m."
            case .serviceArea:
                return "Service area in \(distance)m."
            }
        case .tollCollection(let alert):
            switch alert.type {
            case .booth:
                return "Toll booth in \(distance)m."
            case .gantry:
                return "Toll gantry in \(distance)m."
            }
        default:
            return ""
        }
    }
}
