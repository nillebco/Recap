import Foundation

extension DependencyContainer {
    
    func makePermissionsHelper() -> PermissionsHelperType {
        PermissionsHelper()
    }
    
    func makeEventFileManager() -> EventFileManaging { eventFileManager }
}
