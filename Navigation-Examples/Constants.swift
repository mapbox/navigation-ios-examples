import Foundation
import UIKit

typealias NamedController = (
    name: String,
    description: String,
    controller: UIViewController.Type,
    storyboard: UIStoryboard?, // Is the example containined in a storyboard? If so, we assume the Initial View Controller of the storyboard.
    pushExampleToViewController: Bool // If the example does not go directly into the example,(i.e. another map is shown) set this value to true
)

let listOfExamples: [NamedController] = [
    (
        name: "Advanced Implementation",
        description:"""
        Demonstrates how to display a custom map style and how to apply stylized components in the UI.
        This example also allows the user to select an alternate route. Long press on the map to begin.
        Note: The Directions API will not always return alternate routes.
        """,
        controller: AdvancedViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Basic",
        description: "A basic hello world example showing how to create a navigation experience using the fewest lines of code possible.",
        controller: BasicViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Custom Destination Marker",
        description: "Use a custom image for styling the destination marker.",
        controller: CustomDestinationMarkerController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Embedded View Controller",
        description: "Demonstrates how to embed a NavigationViewController within a parent view controller.",
        controller: EmbeddedExampleViewController.self,
        storyboard: UIStoryboard(name: "EmbeddedExamples", bundle: nil),
        pushExampleToViewController: true
    ),
    (
        name: "Styled UI Elements",
        description: "Demonstrates how to customize various UI elements and also change the map style.",
        controller: CustomStyleUIElements.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Waypoint Arrival Screen",
        description: "Demonstrates how to provide a custom UIView for the user upon arriving at a waypoint.",
        controller: WaypointArrivalScreenViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Custom Waypoint Styling",
        description: "Demonstrates how to customize waypoint styling.",
        controller: CustomWaypointsViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Custom Voice Controller",
        description: "Add custom audio recordings for your instructions.",
        controller: CustomVoiceControllerUI.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Custom Directions Server",
        description: "Use a custom directions server with the Navigation SDK via the Mapbox Map Matching SDK.",
        controller: CustomServerViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Custom Top & Bottom Bars",
        description: "Use a custom UI for top and bottom bars during navigation.",
        controller: CustomBarsViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Route Deserialization",
        description: "Demonstrates how to initialize a Route and deserialize it from JSON.",
        controller: RouteDeserializationViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Route Initialization",
        description: "Demonstrates how to initialize a Route using initializers in code.",
        controller: RouteInitializationViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Building Extrusion",
        description: "Demonstrates how to highlight building extrusion.",
        controller: BuildingExtrusionViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Predictive Caching",
        description: "Demonstrates how to use predictive caching for navigation.",
        controller: PredictiveCachingViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Route Alerts",
        description: "Demonstrates how to display route alerts.",
        controller: RouteAlertsViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    ),
    (
        name: "Snapping locations in standalone map view",
        description: "Demonstrates how to snap user location to the road network in a map view outside of active turn-by-turn navigation. Simulate Navigation option isn't supported here, instead you can use location simulation inside of the Simulator (Features ‣ Location ‣ \"City Bicycle Ride\") to see the difference with and without snapping.",
        controller: LocationSnappingViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Observe electronic horizon events",
        description: "Demonstrates how to use electronic horizon to predict user's most probable path and show upcoming intersections. Simulate Navigation option isn't supported here, instead you can simulate location in Xcode.",
        controller: ElectronicHorizonEventsViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    )
]
