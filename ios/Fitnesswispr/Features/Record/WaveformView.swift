import SwiftUI

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: 4, height: max(4, CGFloat(levels[i]) * 60))
                    .animation(.easeInOut(duration: 0.1), value: levels[i])
            }
        }
        .frame(height: 60)
    }
}
