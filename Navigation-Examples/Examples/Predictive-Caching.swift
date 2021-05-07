import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

class PredictiveCachingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let origin = CLLocationCoordinate2DMake(37.77440680146262, -122.43539772352648)
        let destination = CLLocationCoordinate2DMake(37.76556957793795, -122.42409811526268)
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
                // Since first route is retrieved from response `routeIndex` is set to 0.
                let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options, simulating: simulationIsEnabled ? .always : .onPoorGPS)
                
                // When predictive caching is enabled, the Navigation SDK will create a cache of data within three configurable boundaries.
                var predictiveCacheOptions = PredictiveCacheOptions()
                // Radius around the user's location. Defaults to 2000 meters.
                predictiveCacheOptions.routeBufferRadius = 300
                // Buffer around the route. Defaults to 500 meters.
                predictiveCacheOptions.currentLocationRadius = 2000
                // Radius around the destination. Defaults to 5000 meters.
                predictiveCacheOptions.destinationLocationRadius = 3000
                
                let navigationOptions = NavigationOptions(navigationService: navigationService, predictiveCacheOptions: predictiveCacheOptions)

                let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
                navigationViewController.modalPresentationStyle = .fullScreen
                navigationViewController.routeLineTracksTraversal = true
                
                strongSelf.present(navigationViewController, animated: true)
            }
        }
    }
}
