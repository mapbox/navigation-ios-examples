import Foundation
import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxSpeech
import AVFoundation

class CustomVoiceControllerUI: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let origin = CLLocationCoordinate2DMake(37.77440680146262, -122.43539772352648)
        let destination = CLLocationCoordinate2DMake(37.76556957793795, -122.42409811526268)
        let routeOptions = NavigationRouteOptions(coordinates: [origin, destination])
        
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
                
                // `MultiplexedSpeechSynthesizer` will provide "a backup" functionality to cover cases, which
                // our custom implementation cannot handle.
                let speechSynthesizer = MultiplexedSpeechSynthesizer([CustomVoiceController(), SystemSpeechSynthesizer()] as? [SpeechSynthesizing])
                let routeVoiceController = RouteVoiceController(navigationService: navigationService, speechSynthesizer: speechSynthesizer)
                // Remember to pass our `Voice Controller` to `Navigation Options`!
                let navigationOptions = NavigationOptions(navigationService: navigationService, voiceController: routeVoiceController)
                
                let navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: routeOptions, navigationOptions: navigationOptions)
                navigationViewController.modalPresentationStyle = .fullScreen
                
                strongSelf.present(navigationViewController, animated: true, completion: nil)
            }
        }
    }
}

class CustomVoiceController: MapboxSpeechSynthesizer {
    
    // You will need audio files for as many or few cases as you'd like to handle
    // This example just covers left and right. All other cases will fail the Custom Voice Controller and force a backup System Speech to kick in
    let turnLeft = NSDataAsset(name: "turnleft")!.data
    let turnRight = NSDataAsset(name: "turnright")!.data
    
    override func speak(_ instruction: SpokenInstruction, during legProgress: RouteLegProgress, locale: Locale? = nil) {

        guard let soundForInstruction = audio(for: legProgress.currentStep) else {
            // When `MultiplexedSpeechSynthesizer` receives an error from one of it's Speech Synthesizers,
            // it requests the next on the list
            delegate?.speechSynthesizer(self,
                                        didSpeak: instruction,
                                        with: SpeechError.noData(instruction: instruction,
                                                                 options: SpeechOptions(text: instruction.text)))
            return
        }
        speak(instruction, data: soundForInstruction)
    }
    
    func audio(for step: RouteStep) -> Data? {
        switch step.maneuverDirection {
        case .left:
            return turnLeft
        case .right:
            return turnRight
        default:
            return nil // this will force report that Custom View Controller is unable to handle this case
        }
    }
}
