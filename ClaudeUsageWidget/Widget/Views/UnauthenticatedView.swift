import SwiftUI

struct UnauthenticatedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Open Claude Widget\nto sign in")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    UnauthenticatedView()
        .frame(width: 154, height: 154)
}
