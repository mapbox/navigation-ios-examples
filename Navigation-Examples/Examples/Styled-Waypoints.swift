import Foundation
import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

class StyledWaypointsViewController: UIViewController, NavigationViewControllerDelegate, MGLMapViewDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let origin = Waypoint(coordinate: CLLocationCoordinate2DMake(45.52515652781534, -122.67857551574706), coordinateAccuracy: -1, name: "Origin")
        let pickup = Waypoint(coordinate: CLLocationCoordinate2DMake(45.52054115838411, -122.67076492309569), coordinateAccuracy: -1, name: "Pickup")
        let dropoff = Waypoint(coordinate: CLLocationCoordinate2DMake(45.522885, -122.661773), coordinateAccuracy: -1, name: "Dropoff")
        let destination = Waypoint(coordinate: CLLocationCoordinate2DMake(45.512061121601, -122.65359878540038), coordinateAccuracy: -1, name: "Destination")
        
        let options = NavigationRouteOptions(waypoints: [origin, pickup, dropoff, destination], profileIdentifier: .automobile)
        
        Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let route = routes?.first, error == nil else {
                print(error!.localizedDescription)
                return
            }
            
            let navigationService = MapboxNavigationService(route: route, simulating: simulationIsEnabled ? .always : .onPoorGPS)
            let navigationOptions = NavigationOptions(navigationService: navigationService)
            let navigationViewController = NavigationViewController(for: route, options: navigationOptions)
            navigationViewController.delegate = self
            navigationViewController.mapView?.delegate = self
            
            self.present(navigationViewController, animated: true, completion: nil)
        }
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, shapeFor waypoints: [Waypoint], legIndex: Int) -> MGLShape? {

        var features = [MGLPointFeature]()
        
        for waypoint in waypoints {
            let feature = MGLPointFeature()
            feature.coordinate = waypoint.coordinate
            feature.attributes = [
                "title": waypoint.name!,
                "imageName": waypoint.name!.lowercased()
            ]
            features.append(feature)
        }
        
        return MGLShapeCollectionFeature(shapes: features)
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, waypointStyleLayerWithIdentifier identifier: String, source: MGLSource) -> MGLStyleLayer? {

        let waypointStyleLayer = MGLCircleStyleLayer(identifier: identifier, source: source)
        waypointStyleLayer.circleColor = NSExpression(forConstantValue: UIColor(red: 17/255, green: 129/255, blue: 49/255, alpha: 1.0))
        waypointStyleLayer.circleRadius = NSExpression(forConstantValue: 12)
        waypointStyleLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.lightGray)
        waypointStyleLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)

        return waypointStyleLayer
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, waypointSymbolStyleLayerWithIdentifier identifier: String, source: MGLSource) -> MGLStyleLayer? {
        
        let waypointSymbolStyleLayer = MGLSymbolStyleLayer(identifier: identifier, source: source)
        waypointSymbolStyleLayer.iconImageName = NSExpression(forConditional: NSPredicate(format: "imageName == 'pickup'"), trueExpression: NSExpression(forConstantValue: "pickup"), falseExpression: NSExpression(forConstantValue: "dropoff"))
        waypointSymbolStyleLayer.iconScale = NSExpression(forConstantValue: 0.18)
        waypointSymbolStyleLayer.text = NSExpression(forKeyPath: "title")
        waypointSymbolStyleLayer.textColor = NSExpression(forConstantValue: UIColor.white)
        waypointSymbolStyleLayer.textTranslation = NSExpression(forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: 20)))
        waypointSymbolStyleLayer.textJustification = NSExpression(forConstantValue: "center")
        waypointSymbolStyleLayer.textAnchor = NSExpression(forConstantValue: "center")
        
        return waypointSymbolStyleLayer
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        style.setImage(UIImage(named: "pickup")!, forName: "pickup")
        style.setImage(UIImage(named: "dropoff")!, forName: "dropoff")
    }
}
