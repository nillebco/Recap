import XCTest
import Combine
import Mockable
@testable import Recap

@MainActor
final class GeneralSettingsViewModelSpec: XCTestCase {
    private var sut: GeneralSettingsViewModel!
    private var mockLLMService: MockLLMServiceType!
    private var mockUserPreferencesRepository: MockUserPreferencesRepositoryType!
    private var mockKeychainAPIValidator: MockKeychainAPIValidatorType!
    private var mockKeychainService: MockKeychainServiceType!
    private var mockWarningManager: MockWarningManagerType!
    private var mockFileManagerHelper: RecordingFileManagerHelperType!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockLLMService = MockLLMServiceType()
        mockUserPreferencesRepository = MockUserPreferencesRepositoryType()
        mockKeychainAPIValidator = MockKeychainAPIValidatorType()
        mockKeychainService = MockKeychainServiceType()
        mockWarningManager = MockWarningManagerType()
        mockFileManagerHelper = TestRecordingFileManagerHelper()
    }
    
    private func initSut(
        preferences: UserPreferencesInfo = UserPreferencesInfo(
            selectedProvider: .ollama,
            autoDetectMeetings: false,
            autoStopRecording: false
        ),
        availableModels: [LLMModelInfo] = [],
        selectedModel: LLMModelInfo? = nil,
        warnings: [WarningItem] = []
    ) async {
        given(mockWarningManager)
            .activeWarningsPublisher
            .willReturn(Just(warnings).eraseToAnyPublisher())
        
        given(mockLLMService)
            .getUserPreferences()
            .willReturn(preferences)
        
        given(mockLLMService)
            .getAvailableModels()
            .willReturn(availableModels)
        
        given(mockLLMService)
            .getSelectedModel()
            .willReturn(selectedModel)
        
        sut = GeneralSettingsViewModel(
            llmService: mockLLMService,
            userPreferencesRepository: mockUserPreferencesRepository,
            keychainAPIValidator: mockKeychainAPIValidator,
            keychainService: mockKeychainService,
            warningManager: mockWarningManager,
            fileManagerHelper: mockFileManagerHelper
        )
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockLLMService = nil
        mockUserPreferencesRepository = nil
        mockKeychainAPIValidator = nil
        mockKeychainService = nil
        mockWarningManager = nil
        mockFileManagerHelper = nil
        cancellables.removeAll()
        
        try await super.tearDown()
    }
    
    func testInitialState() async throws {
        await initSut()
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.selectedProvider, .ollama)
        XCTAssertFalse(sut.autoDetectMeetings)
        XCTAssertFalse(sut.isAutoStopRecording)
    }
    
    func testLoadModelsSuccess() async throws {
        let testModels = [
            LLMModelInfo(id: "model1", name: "Model 1", provider: "ollama"),
            LLMModelInfo(id: "model2", name: "Model 2", provider: "ollama")
        ]
        
        await initSut(
            availableModels: testModels,
            selectedModel: testModels[0]
        )
        
        XCTAssertEqual(sut.availableModels.count, 2)
        XCTAssertEqual(sut.selectedModel?.id, "model1")
        XCTAssertTrue(sut.hasModels)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoadModelsError() async throws {
        given(mockWarningManager)
            .activeWarningsPublisher
            .willReturn(Just([]).eraseToAnyPublisher())
        
        given(mockLLMService)
            .getUserPreferences()
            .willReturn(UserPreferencesInfo(
                selectedProvider: .ollama,
                autoDetectMeetings: false,
                autoStopRecording: false
            ))
        
        given(mockLLMService)
            .getAvailableModels()
            .willThrow(NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
        
        given(mockLLMService)
            .getSelectedModel()
            .willReturn(nil)
        
        sut = GeneralSettingsViewModel(
            llmService: mockLLMService,
            userPreferencesRepository: mockUserPreferencesRepository,
            keychainAPIValidator: mockKeychainAPIValidator,
            keychainService: mockKeychainService,
            warningManager: mockWarningManager,
            fileManagerHelper: mockFileManagerHelper
        )
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("Test error") ?? false)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.availableModels.count, 0)
    }
    
    func testSelectModelSuccess() async throws {
        await initSut()
        
        let testModel = LLMModelInfo(id: "model1", name: "Model 1", provider: "ollama")
        
        given(mockLLMService)
            .selectModel(id: .value("model1"))
            .willReturn()
        
        await sut.selectModel(testModel)
        
        XCTAssertEqual(sut.selectedModel?.id, "model1")
        XCTAssertNil(sut.errorMessage)
        
        verify(mockLLMService)
            .selectModel(id: .value("model1"))
            .called(1)
    }
    
    func testSelectModelError() async throws {
        await initSut()
        
        let testModel = LLMModelInfo(id: "model1", name: "Model 1", provider: "ollama")
        
        given(mockLLMService)
            .selectModel(id: .any)
            .willThrow(NSError(domain: "TestError", code: 500))
        
        await sut.selectModel(testModel)
        
        XCTAssertNil(sut.selectedModel)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testSelectProviderOllama() async throws {
        let testModels = [
            LLMModelInfo(id: "ollama1", name: "Ollama Model", provider: "ollama")
        ]
        
        given(mockWarningManager)
            .activeWarningsPublisher
            .willReturn(Just([]).eraseToAnyPublisher())
        
        given(mockLLMService)
            .getUserPreferences()
            .willReturn(UserPreferencesInfo(
                selectedProvider: .ollama,
                autoDetectMeetings: false,
                autoStopRecording: false
            ))
        
        given(mockLLMService)
            .getAvailableModels()
            .willReturn([])
            .getAvailableModels()
            .willReturn(testModels)
        
        given(mockLLMService)
            .getSelectedModel()
            .willReturn(nil)
            .getSelectedModel()
            .willReturn(testModels[0])
        
        given(mockLLMService)
            .selectProvider(.value(.ollama))
            .willReturn()
        
        sut = GeneralSettingsViewModel(
            llmService: mockLLMService,
            userPreferencesRepository: mockUserPreferencesRepository,
            keychainAPIValidator: mockKeychainAPIValidator,
            keychainService: mockKeychainService,
            warningManager: mockWarningManager,
            fileManagerHelper: mockFileManagerHelper
        )
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await sut.selectProvider(.ollama)
        
        XCTAssertEqual(sut.selectedProvider, .ollama)
        XCTAssertEqual(sut.availableModels.count, 1)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSelectProviderOpenRouterWithoutAPIKey() async throws {
        await initSut()
        
        given(mockKeychainAPIValidator)
            .validateOpenRouterAPI()
            .willReturn(.missingApiKey)
        
        given(mockKeychainService)
            .retrieve(key: .value(KeychainKey.openRouterApiKey.key))
            .willReturn(nil)
        
        await sut.selectProvider(.openRouter)
        
        XCTAssertTrue(sut.showAPIKeyAlert)
        XCTAssertNil(sut.existingAPIKey)
        XCTAssertNotEqual(sut.selectedProvider, .openRouter)
    }
    
    func testSelectProviderOpenRouterWithValidAPIKey() async throws {
        await initSut()
        
        given(mockKeychainAPIValidator)
            .validateOpenRouterAPI()
            .willReturn(.valid)
        
        let testModels = [
            LLMModelInfo(id: "openrouter1", name: "OpenRouter Model", provider: "openrouter")
        ]
        
        given(mockLLMService)
            .selectProvider(.value(.openRouter))
            .willReturn()
        
        given(mockLLMService)
            .getAvailableModels()
            .willReturn(testModels)
        
        given(mockLLMService)
            .getSelectedModel()
            .willReturn(nil)
        
        given(mockLLMService)
            .selectModel(id: .any)
            .willReturn()
        
        await sut.selectProvider(.openRouter)
        
        XCTAssertEqual(sut.selectedProvider, .openRouter)
        XCTAssertFalse(sut.showAPIKeyAlert)
    }
    
    func testToggleAutoDetectMeetingsSuccess() async throws {
        await initSut()
        
        given(mockUserPreferencesRepository)
            .updateAutoDetectMeetings(.value(true))
            .willReturn()
        
        await sut.toggleAutoDetectMeetings(true)
        
        XCTAssertTrue(sut.autoDetectMeetings)
        XCTAssertNil(sut.errorMessage)
        
        verify(mockUserPreferencesRepository)
            .updateAutoDetectMeetings(.value(true))
            .called(1)
    }
    
    func testToggleAutoDetectMeetingsError() async throws {
        await initSut()
        
        given(mockUserPreferencesRepository)
            .updateAutoDetectMeetings(.any)
            .willThrow(NSError(domain: "TestError", code: 500))
        
        await sut.toggleAutoDetectMeetings(true)
        
        XCTAssertFalse(sut.autoDetectMeetings)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testToggleAutoStopRecordingSuccess() async throws {
        await initSut()
        
        given(mockUserPreferencesRepository)
            .updateAutoStopRecording(.value(true))
            .willReturn()
        
        await sut.toggleAutoStopRecording(true)
        
        XCTAssertTrue(sut.isAutoStopRecording)
        XCTAssertNil(sut.errorMessage)
        
        verify(mockUserPreferencesRepository)
            .updateAutoStopRecording(.value(true))
            .called(1)
    }
    
    func testSaveAPIKeySuccess() async throws {
        await initSut()
        
        given(mockKeychainService)
            .store(key: .value(KeychainKey.openRouterApiKey.key), value: .value("test-api-key"))
            .willReturn()
        
        given(mockKeychainAPIValidator)
            .validateOpenRouterAPI()
            .willReturn(.valid)
        
        given(mockLLMService)
            .selectProvider(.value(.openRouter))
            .willReturn()
        
        given(mockLLMService)
            .getAvailableModels()
            .willReturn([])
        
        given(mockLLMService)
            .getSelectedModel()
            .willReturn(nil)
        
        try await sut.saveAPIKey("test-api-key")
        
        XCTAssertFalse(sut.showAPIKeyAlert)
        XCTAssertEqual(sut.existingAPIKey, "test-api-key")
        XCTAssertEqual(sut.selectedProvider, .openRouter)
    }
    
    func testDismissAPIKeyAlert() async throws {
        await initSut()
        
        given(mockKeychainAPIValidator)
            .validateOpenRouterAPI()
            .willReturn(.missingApiKey)
        
        given(mockKeychainService)
            .retrieve(key: .value(KeychainKey.openRouterApiKey.key))
            .willReturn("existing-key")
        
        await sut.selectProvider(.openRouter)
        
        XCTAssertTrue(sut.showAPIKeyAlert)
        XCTAssertEqual(sut.existingAPIKey, "existing-key")

        sut.dismissAPIKeyAlert()
        
        XCTAssertFalse(sut.showAPIKeyAlert)
        XCTAssertNil(sut.existingAPIKey)
    }
    
    func testWarningManagerIntegration() async throws {
        let testWarnings = [
            WarningItem(id: "1", title: "Test Warning", message: "Test warning message")
        ]

        let warningPublisher = PassthroughSubject<[WarningItem], Never>()
        given(mockWarningManager)
            .activeWarningsPublisher
            .willReturn(warningPublisher.eraseToAnyPublisher())

        given(mockLLMService)
            .getUserPreferences()
            .willReturn(UserPreferencesInfo(
                selectedProvider: .ollama,
                autoDetectMeetings: false,
                autoStopRecording: false
            ))

        given(mockLLMService)
            .getAvailableModels()
            .willReturn([])

        given(mockLLMService)
            .getSelectedModel()
            .willReturn(nil)

        sut = GeneralSettingsViewModel(
            llmService: mockLLMService,
            userPreferencesRepository: mockUserPreferencesRepository,
            keychainAPIValidator: mockKeychainAPIValidator,
            keychainService: mockKeychainService,
            warningManager: mockWarningManager,
            fileManagerHelper: mockFileManagerHelper
        )

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.activeWarnings.count, 0)

        warningPublisher.send(testWarnings)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.activeWarnings.count, 1)
        XCTAssertEqual(sut.activeWarnings.first?.title, "Test Warning")
    }
}

private final class TestRecordingFileManagerHelper: RecordingFileManagerHelperType {
    private(set) var baseDirectory: URL

    init(baseDirectory: URL = URL(fileURLWithPath: "/tmp/recap-tests", isDirectory: true)) {
        self.baseDirectory = baseDirectory
    }

    func getBaseDirectory() -> URL {
        baseDirectory
    }

    func setBaseDirectory(_ url: URL, bookmark: Data?) throws {
        baseDirectory = url
    }

    func createRecordingDirectory(for recordingID: String) throws -> URL {
        baseDirectory.appendingPathComponent(recordingID, isDirectory: true)
    }
}
