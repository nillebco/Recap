import Foundation
import Combine

protocol AudioProcessControllerType: ObservableObject {
    var processes: [AudioProcess] { get }
    var processGroups: [AudioProcessGroup] { get }
    var meetingApps: [AudioProcess] { get }
    
    func activate()
}