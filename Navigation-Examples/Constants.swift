import Foundation
import UIKit

typealias NamedController = (
    name: String,
    description: String,
    controller: UIViewController.Type,
    storyboard: UIStoryboard?, //is the example containined in a storyboard? If so, we assume the Initial View Controller of the storyboard.
    pushExampleToViewController: Bool // If the example does not go directly into the example,(i.e. another map is shown) set this value to true
)

let listOfExamples: [NamedController] = [
    (
        name: "Advanced Implementation",
        description: "Demonstrates how to display a custom map style and how to apply stylized components in the UI. Long press on the map to begin.",
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
        pushExampleToViewController: false
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
        name: "Select Alternate Route",
        description: "Allow the user to select an alternate route. Note: The Directions API will not always return alternate routes.",
        controller: AdvancedViewController.self,
        storyboard: nil,
        pushExampleToViewController: true
    ),
    (
        name: "Waypoint Arrival Screen",
        description: "Demonstrates how to provide a custom UIView for the user upon arriving at a waypoint.",
        controller: WaypointArrivalScreenViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
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
        name: "Styled Waypoints",
        description: "Customize the style of waypoints within a route",
        controller: StyledWaypointsViewController.self,
        storyboard: nil,
        pushExampleToViewController: false
    )
]
