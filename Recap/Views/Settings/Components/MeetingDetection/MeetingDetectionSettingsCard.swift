import SwiftUI
import ScreenCaptureKit

struct MeetingDetectionSettingsCard<GeneralViewModel: GeneralSettingsViewModelType, MeetingViewModel: MeetingDetectionSettingsViewModelType>: View {
    @ObservedObject private var generalSettingsViewModel: GeneralViewModel
    @ObservedObject private var viewModel: MeetingViewModel
    
    init(generalSettingsViewModel: GeneralViewModel, viewModel: MeetingViewModel) {
        self.generalSettingsViewModel = generalSettingsViewModel
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
                SettingsCard(title: "Meeting Detection") {
                    if viewModel.autoDetectMeetings && !viewModel.hasScreenRecordingPermission {
                        WarningCard(
                            warning: WarningItem(
                                id: "screen-recording",
                                title: "Permission Required",
                                message: "Screen Recording permission needed to detect meeting windows",
                                icon: "exclamationmark.shield",
                                severity: .warning
                            ),
                            containerWidth: geometry.size.width
                        )
                    }
                    
                VStack(spacing: 16) {
                    settingsRow(
                        label: "Auto-detect meetings",
                        description: "Get notified in console when Teams, Zoom, or Meet meetings begin"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { viewModel.autoDetectMeetings },
                            set: { newValue in
                                Task {
                                    await viewModel.handleAutoDetectToggle(newValue)
                                }
                            }
                        ))
                        .toggleStyle(CustomToggleStyle())
                        .labelsHidden()
                    }
                    
                    if viewModel.autoDetectMeetings {
                        VStack(spacing: 12) {
                            if !viewModel.hasScreenRecordingPermission {
                                VStack(alignment: .leading, spacing: 8) {
                                    PillButton(
                                        text: "Open System Settings",
                                        icon: "gear"
                                    ) {
                                        viewModel.openScreenRecordingPreferences()
                                    }
                                    
                                    Text("This permission allows Recap to read window titles only. No screen content is captured or recorded.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 12))
                                    Text("Screen Recording permission granted")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
        }
        .onAppear {
            Task {
                await viewModel.checkPermissionStatus()
            }
        }
        .onChange(of: viewModel.autoDetectMeetings) { enabled in
            if enabled {
                Task {
                    await viewModel.checkPermissionStatus()
                }
            }
        }
    }
    }
    
    private func settingsRow<Content: View>(
        label: String,
        description: String? = nil,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UIConstants.Colors.textPrimary)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            control()
        }
    }
    
}
