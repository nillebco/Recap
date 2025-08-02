import Foundation
import SwiftUI
import OSLog
import Combine

@MainActor
protocol RecapViewModelDelegate: AnyObject {
    func didRequestSettingsOpen()
    func didRequestViewOpen()
    func didRequestPreviousRecapsOpen()
}

@MainActor
final class RecapViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var microphoneLevel: Float = 0.0
    @Published var systemAudioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published private(set) var selectedApp: AudioProcess?
    @Published var isMicrophoneEnabled = false
    @Published var currentRecordings: [RecordingInfo] = []
    @Published private(set) var processingState: ProcessingState = .idle
    @Published private(set) var activeWarnings: [WarningItem] = []
    
    let recordingCoordinator: RecordingCoordinator
    let processingCoordinator: ProcessingCoordinator
    let recordingRepository: RecordingRepositoryType
    let appSelectionViewModel: AppSelectionViewModel
    let fileManager: RecordingFileManaging
    let warningManager: WarningManagerType
    var timer: Timer?
    var levelTimer: Timer?
    let logger = Logger(subsystem: "com.recap.audio", category: String(describing: RecapViewModel.self))
    weak var delegate: RecapViewModelDelegate?
    var currentRecordingID: String?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        recordingCoordinator: RecordingCoordinator,
        processingCoordinator: ProcessingCoordinator,
        recordingRepository: RecordingRepositoryType,
        appSelectionViewModel: AppSelectionViewModel,
        fileManager: RecordingFileManaging,
        warningManager: WarningManagerType
    ) {
        self.recordingCoordinator = recordingCoordinator
        self.processingCoordinator = processingCoordinator
        self.recordingRepository = recordingRepository
        self.appSelectionViewModel = appSelectionViewModel
        self.fileManager = fileManager
        self.warningManager = warningManager
        
        setupBindings()
        setupWarningObserver()
        appSelectionViewModel.delegate = self
        processingCoordinator.delegate = self
        
        Task {
            await loadRecordings()
        }
    }
    
    func selectApp(_ app: AudioProcess) {
        selectedApp = app
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func refreshApps() {
        appSelectionViewModel.refreshAvailableApps()
    }
    
    var currentRecordingLevel: Float {
        recordingCoordinator.currentAudioLevel
    }
    
    
    var hasAvailableApps: Bool {
        !appSelectionViewModel.availableApps.isEmpty
    }
    
    var canStartRecording: Bool {
        selectedApp != nil
    }
    
    func toggleMicrophone() {
        isMicrophoneEnabled.toggle()
    }
    
    var systemAudioHeatmapLevel: Float {
        guard isRecording else { return 0 }
        return systemAudioLevel
    }
    
    var microphoneHeatmapLevel: Float {
        guard isRecording && isMicrophoneEnabled else { return 0 }
        return microphoneLevel
    }
    
    private func setupBindings() {
        appSelectionViewModel.refreshAvailableApps()
    }
    
    private func setupWarningObserver() {
        warningManager.activeWarningsPublisher
            .assign(to: \.activeWarnings, on: self)
            .store(in: &cancellables)
    }
    
    private func loadRecordings() async {
        do {
            currentRecordings = try await recordingRepository.fetchAllRecordings()
        } catch {
            logger.error("Failed to load recordings: \(error)")
        }
    }
    
    func retryProcessing(for recordingID: String) async {
        await processingCoordinator.retryProcessing(recordingID: recordingID)
    }
    
    func updateRecordingUIState(started: Bool) {
        isRecording = started
        if started {
            recordingDuration = 0
            startTimers()
        } else {
            stopTimers()
            recordingDuration = 0
            microphoneLevel = 0.0
            systemAudioLevel = 0.0
        }
    }
    
    deinit {
        Task.detached { [weak self] in
            await self?.stopTimers()
        }
    }
}

extension RecapViewModel: AppSelectionDelegate {
    func didSelectApp(_ app: AudioProcess) {
        selectApp(app)
    }
    
    func didClearAppSelection() {
        selectedApp = nil
    }
}

extension RecapViewModel {
    func openSettings() {
        delegate?.didRequestSettingsOpen()
    }
    
    func openView() {
        delegate?.didRequestViewOpen()
    }
    
    func openPreviousRecaps() {
        delegate?.didRequestPreviousRecapsOpen()
    }
}

#if DEBUG
extension RecapViewModel {
    static func createForPreview() -> RecapViewModel {
        let container = DependencyContainer.createForPreview()
        return container.createRecapViewModel()
    }
}
#endif
