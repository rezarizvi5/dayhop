import SwiftUI
import UIKit

enum Theme {
    static let cobalt = Color(red: 31 / 255, green: 45 / 255, blue: 230 / 255)
    static let clay = Color(red: 212 / 255, green: 85 / 255, blue: 42 / 255)
    static let leaf = Color(red: 47 / 255, green: 125 / 255, blue: 74 / 255)

    static var paper: Color { dynamic(light: (244, 241, 234), dark: (20, 22, 28)) }
    static var card: Color { dynamic(light: (255, 252, 247), dark: (32, 35, 43)) }
    static var ink: Color { dynamic(light: (28, 25, 21), dark: (243, 239, 230)) }
    static var muted: Color { dynamic(light: (74, 69, 60), dark: (196, 190, 178)) }
    static var line: Color { dynamic(light: (226, 220, 208), dark: (58, 62, 72)) }

    static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        })
    }
}

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 3 {
            hex = hex.map { String($0) + String($0) }.joined()
        }
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

struct PrimaryButton: View {
    var title: String
    var tall = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(tall ? .title2.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: tall ? 72 : 52)
                .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: tall ? 20 : 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct SecondaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PaperScreen<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(24)
        }
        .background(Theme.paper.ignoresSafeArea())
    }
}

struct DayHopCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
