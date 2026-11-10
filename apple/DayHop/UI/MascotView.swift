import SwiftUI

enum MascotState {
    case idle
    case cheer
    case celebrate
    case encourage
    case sleepy
}

struct MascotView: View {
    var characterID: String
    var state: MascotState
    var reduceMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduce
    @State private var bob = false

    private var character: (id: String, name: String, hex: String) { Catalog.character(id: characterID) }
    private var color: Color { Color(hex: character.hex) }
    private var still: Bool { reduceMotion || systemReduce || ProcessInfo.processInfo.isLowPowerModeEnabled }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                shape
                    .frame(width: 168, height: 168)
                    .scaleEffect(still ? 1 : (state == .celebrate ? 1.06 : state == .cheer ? 1.04 : 1))
                    .rotationEffect(.degrees(!still && state == .encourage ? 6 : 0))
                    .offset(y: !still && bob && state == .idle ? -6 : 0)
                if state == .celebrate {
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundStyle(Theme.clay)
                        .offset(x: 70, y: -60)
                        .accessibilityHidden(true)
                }
                if state == .sleepy {
                    Text("z")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                        .offset(x: 62, y: -58)
                        .accessibilityHidden(true)
                }
            }
            Text(character.name)
                .font(.headline)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.name)
        .onAppear {
            guard !still else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    @ViewBuilder private var shape: some View {
        let eyesClosed = state == .sleepy
        switch character.id {
        case "bo":
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous).fill(color)
                ear.offset(x: -38, y: -62)
                ear.offset(x: 38, y: -62)
                eyes(closed: eyesClosed).offset(y: -8)
                smile.offset(y: 28)
            }
        case "juniper":
            ZStack {
                Capsule().fill(color)
                Ellipse().fill(Theme.leaf).frame(width: 36, height: 22).rotationEffect(.degrees(-30)).offset(x: 18, y: -78)
                eyes(closed: eyesClosed).offset(y: 6)
                smile.offset(y: 36)
            }
        default:
            ZStack {
                Circle().fill(color)
                beak.offset(x: 46, y: 8)
                eyes(closed: eyesClosed).offset(y: -10)
                smile.offset(y: 24)
            }
        }
    }

    private var ear: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 28, height: 36)
    }

    private var beak: some View {
        Image(systemName: "triangle.fill")
            .font(.title3)
            .foregroundStyle(Color(hex: "#F4C95D"))
            .rotationEffect(.degrees(90))
    }

    private func eyes(closed: Bool) -> some View {
        HStack(spacing: 28) {
            eye(closed: closed)
            eye(closed: closed)
        }
    }

    private func eye(closed: Bool) -> some View {
        Capsule()
            .fill(Color(hex: "#1C1915"))
            .frame(width: closed ? 18 : 14, height: closed ? 4 : 18)
    }

    private var smile: some View {
        Capsule()
            .fill(Color(hex: "#1C1915").opacity(0.85))
            .frame(width: 28, height: 6)
    }
}

struct IconGlyph: View {
    var key: String
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: IconCatalog.symbol(for: key))
            .font(.system(size: size))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHidden(true)
    }
}
