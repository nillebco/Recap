import Foundation
import SwiftUI

struct TranscriptDropdownButton: View {
    let transcriptText: String
    let structuredTranscriptions: [StructuredTranscription]?
    
    @State private var isCollapsed: Bool = true
    
    init(transcriptText: String, structuredTranscriptions: [StructuredTranscription]? = nil) {
        self.transcriptText = transcriptText
        self.structuredTranscriptions = structuredTranscriptions
    }
    
    private var displayText: String {
        // Use pretty formatted version if structured transcriptions are available, otherwise fall back to raw text
        if let structuredTranscriptions = structuredTranscriptions, !structuredTranscriptions.isEmpty {
            return StructuredTranscriptionFormatter.formatForCopyingEnhanced(structuredTranscriptions)
        } else {
            return transcriptText
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .bold))
    
                
            VStack(alignment: .leading) {
                Text("Transcript")
                    .font(UIConstants.Typography.cardTitle)
                    .foregroundColor(UIConstants.Colors.textPrimary)
                
                VStack {
                    
                    if !isCollapsed {
                        Text(displayText)
                            .font(.system(size: 12))
                            .foregroundColor(UIConstants.Colors.textSecondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Spacer()
        
        }
        .frame(alignment: .topLeading)
        .padding(.horizontal, UIConstants.Spacing.cardPadding + 4)
        .padding(.vertical, UIConstants.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(UIConstants.Colors.cardSecondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            UIConstants.Gradients.standardBorder,
                            lineWidth: 1
                        )
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCollapsed.toggle()
            }
        }
    }
}

#Preview {
    GeometryReader { geometry in
        VStack(spacing: 16) {
            TranscriptDropdownButton(
                transcriptText: "Lorem ipsum dolor sit amet",
                structuredTranscriptions: nil
            )
        }
        .padding(20)
    }
    .frame(width: 500, height: 300)
    .background(UIConstants.Gradients.backgroundGradient)
}
