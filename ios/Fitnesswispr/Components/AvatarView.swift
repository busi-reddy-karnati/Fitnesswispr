import SwiftUI

struct AvatarView: View {
    let imageData: Data?
    let initials: String
    var size: CGFloat = 40
    var ringColor: Color? = nil

    var body: some View {
        ZStack {
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.appAccent.opacity(0.18))
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 2.5)
        )
    }
}
