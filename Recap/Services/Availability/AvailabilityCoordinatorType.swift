import Foundation
import Combine

@MainActor
protocol AvailabilityCoordinatorType: AnyObject {
    var isAvailable: Bool { get }
    var availabilityPublisher: AnyPublisher<Bool, Never> { get }
    
    func startMonitoring()
    func stopMonitoring()
    func checkAvailabilityNow() async -> Bool
}