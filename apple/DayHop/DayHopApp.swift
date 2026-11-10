import AVFoundation
import SwiftUI

@main
struct DayHopApp: App {
    @StateObject private var store = HouseholdStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.cobalt)
                .onAppear(perform: configureAudio)
        }
    }

    private func configureAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

struct RootView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.showOnboarding {
                OnboardingView()
            } else if store.snapshot.kidMode {
                KidRootView()
            } else {
                ParentRootView()
            }
        }
        .onAppear { store.launch() }
        .onChange(of: scenePhase, perform: { phase in
            if phase == .active { store.becameActive() }
        })
        .fullScreenCover(item: Binding(get: { store.gate }, set: { store.gate = $0 })) { purpose in
            GateView(purpose: purpose)
        }
    }
}

enum Speaker {
    static let synth = AVSpeechSynthesizer()

    static func speak(_ text: String, enabled: Bool) {
        guard enabled else { return }
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.46
        synth.speak(utterance)
    }

    static func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

enum Cue {
    static func play(_ name: String, enabled: Bool) {
        guard enabled else { return }
        let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else { return }
        players[name] = player
        player.currentTime = 0
        player.play()
    }

    private static var players: [String: AVAudioPlayer] = [:]
}
