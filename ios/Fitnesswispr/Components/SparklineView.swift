import SwiftUI

struct SparklineView: View {
    let values: [Double]
    var width: CGFloat = 52
    var height: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            Path { path in
                for (i, pt) in pts.enumerated() {
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = max(maxV - minV, 0.0001)
        return values.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                y: size.height * (1 - CGFloat((value - minV) / span))
            )
        }
    }
}
