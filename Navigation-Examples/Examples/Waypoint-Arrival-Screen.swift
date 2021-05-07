import Foundation
import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

class WaypointArrivalScreenViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let waypointOne = Waypoint(coordinate: CLLocationCoordinate2DMake(37.777655950348475, -122.43199467658997))
        let waypointTwo = Waypoint(coordinate: CLLocationCoordinate2DMake(37.776087132342745, -122.4329173564911))
        let waypointThree = Waypoint(coordinate: CLLocationCoordinate2DMake(37.775357832637184, -122.43493974208832))
        
        let routeOptions = NavigationRouteOptions(waypoints: [waypointOne, waypointTwo, waypointThree])
        
        Directions.shared.calculate(routeOptions) { [weak self] (_, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
                let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: routeOptions, simulating: simulationIsEnabled ? .always : .onPoorGPS)
                let navigationOptions = NavigationOptions(navigationService: navigationService)
                let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: routeOptions, navigationOptions: navigationOptions)
                navigationViewController.modalPresentationStyle = .fullScreen
                navigationViewController.delegate = strongSelf
                
                strongSelf.present(navigationViewController, animated: true, completion: nil)
            }
        }
    }
}

extension WaypointArrivalScreenViewController: NavigationViewControllerDelegate {
    // Show an alert when arriving at the waypoint and wait until the user to start next leg.
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        let isFinalLeg = navigationViewController.navigationService.routeProgress.isFinalLeg
        if isFinalLeg {
            return true
        }
        
        let alert = UIAlertController(title: "Arrived at \(waypoint.name ?? "Unknown").", message: "Would you like to continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            // Begin the next leg once the driver confirms
            if !isFinalLeg {
                navigationViewController.navigationService.routeProgress.legIndex += 1
                navigationViewController.navigationService.start()
            }
        }))
        navigationViewController.present(alert, animated: true, completion: nil)
        
        return false
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        dismiss(animated: true, completion: nil)
    }
}
