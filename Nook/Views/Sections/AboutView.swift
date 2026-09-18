import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image("NookAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.nookBorder, lineWidth: 1)
                )
            Text("Nook")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(version)
                .foregroundStyle(Color.nookSecondaryText)
            Text("System-wide text expansion that stays out of your way.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nookSecondaryText)
                .frame(maxWidth: 320)
            Divider()
                .overlay(Color.nookBorder)
                .frame(maxWidth: 280)
            Text("Open source. Snippets are stored locally as JSON in\n~/Library/Application Support/Nook.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nookSecondaryText.opacity(0.8))
            Text("Made with ❤️ by Vlad and Claude")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nookSecondaryText.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nookBackground)
        .navigationTitle("About")
    }
}
