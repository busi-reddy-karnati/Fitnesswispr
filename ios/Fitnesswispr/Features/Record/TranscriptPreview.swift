import SwiftUI

struct TranscriptPreview: View {
    let transcript: String

    var body: some View {
        ScrollView {
            Text(transcript.isEmpty ? "Listening..." : transcript)
                .font(.body)
                .foregroundColor(transcript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxHeight: 120)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
