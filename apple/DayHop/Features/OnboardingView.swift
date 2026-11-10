import Network
import SwiftUI

final class Reachability: ObservableObject {
    @Published var online = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.online = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "dayhop.reachability"))
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var store: HouseholdStore
    @StateObject private var reachability = Reachability()
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var house = ""
    @State private var zone = TimeZone.current.identifier
    @State private var agreed = false
    @State private var nickname = ""
    @State private var age: AgeBand = .five
    @State private var characterID = "pip"
    @State private var accent = Catalog.accents[0]
    @State private var kidID: UUID?
    @State private var pin = ""
    @State private var confirm = ""
    @State private var confirming = false
    @State private var templateChoices = Catalog.templates()

    var body: some View {
        PaperScreen {
            switch store.snapshot.onboardStep {
            case 0: welcome
            case 1: signIn
            case 2: adult
            case 3: household
            case 4: consent
            case 5: kidForm
            case 6: templates
            default: pinForm
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            MascotView(characterID: "pip", state: .idle, reduceMotion: false)
            Text(Copy.welcome1Title).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.welcome1Body).font(.body).foregroundStyle(Theme.ink)
            Text(Copy.welcome2Title).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.welcome2Body).font(.body).foregroundStyle(Theme.ink)
            Text(Copy.welcome3Title).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.welcome3Body).font(.body).foregroundStyle(Theme.ink)
            PrimaryButton(title: Copy.next) { store.skipToSignIn() }
            SecondaryButton(title: Copy.skip) { store.skipToSignIn() }
            Button(Copy.preview) { store.loadSample() }
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Copy.signIn).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            if !reachability.online {
                Text(CloudConfig.load().isConfigured ? Copy.offlineBlock : Copy.offline).font(.body).foregroundStyle(Theme.ink)
            }
            if let notice = store.authNotice {
                Text(notice).font(.body).foregroundStyle(Theme.ink)
            }
            providerButton(Copy.apple, filled: true) { Task { await startProvider("apple") } }
            providerButton(Copy.google, filled: false) { Task { await startProvider("google") } }
            TextField(Copy.emailHint, text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
            SecureField(Copy.passwordHint, text: $password)
                .textContentType(.password)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
            PrimaryButton(title: Copy.email) { submitEmail() }
            if let message {
                Text(message).font(.body).foregroundStyle(Theme.ink)
            }
            Text(Copy.signedOutHint).font(.subheadline).foregroundStyle(Theme.muted)
            if store.snapshot.email.isEmpty && store.snapshot.kids.isEmpty {
                Button(Copy.preview) { store.loadSample() }.frame(minHeight: 44)
            }
        }
    }

    private var adult: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.adultTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            PrimaryButton(title: Copy.adultYes) { store.confirmAdult() }
            SecondaryButton(title: Copy.adultNo) { store.declineAdult() }
            Text(Copy.adultDeclined).font(.body).foregroundStyle(Theme.muted)
        }
    }

    private var household: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.householdTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            TextField(Copy.householdField, text: $house)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            Picker(Copy.timezone, selection: $zone) {
                ForEach(zones, id: \.self) { Text($0).tag($0) }
            }
            .frame(minHeight: 44)
            if let message { Text(message).foregroundStyle(Theme.ink) }
            PrimaryButton(title: Copy.next) {
                message = store.setHousehold(name: house, timeZoneID: zone) ? nil : Copy.householdName
            }
        }
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.consentTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.consentBody).font(.body).foregroundStyle(Theme.ink)
            Text(Copy.policyVersion).font(.subheadline).foregroundStyle(Theme.muted)
            Toggle(Copy.consentCheck, isOn: $agreed).frame(minHeight: 44)
            PrimaryButton(title: Copy.next) { if agreed { store.recordConsent() } }
                .disabled(!agreed)
                .opacity(agreed ? 1 : 0.45)
        }
    }

    private var kidForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.kidTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            TextField(Copy.nickname, text: $nickname).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            Picker(Copy.ageBand, selection: $age) {
                ForEach(AgeBand.allCases) { band in Text(band.rawValue).tag(band) }
            }
            Text(age.preReader ? Copy.preReader : Copy.reader).font(.subheadline).foregroundStyle(Theme.muted)
            Text(Copy.character).font(.headline)
            HStack(spacing: 12) {
                ForEach(Catalog.characters, id: \.id) { item in
                    Button { characterID = item.id } label: {
                        MascotView(characterID: item.id, state: .idle, reduceMotion: true)
                            .padding(6)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(characterID == item.id ? Theme.cobalt : Color.clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(characterID == item.id ? .isSelected : [])
                }
            }
            Text(Copy.colour).font(.headline)
            HStack(spacing: 10) {
                ForEach(Catalog.accents, id: \.self) { hex in
                    Button { accent = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: accent == hex ? 3 : 0))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(hex)
                }
            }
            if let message { Text(message).foregroundStyle(Theme.ink) }
            PrimaryButton(title: Copy.next) { saveKid() }
        }
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.templateTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            if let message { Text(message).foregroundStyle(Theme.ink) }
            ForEach(templateChoices) { template in
                Button {
                    guard let kidID = kidID ?? store.activeKids.last?.id else { return }
                    var copy = template
                    copy.kidIDs = [kidID]
                    message = saveIssue(store.saveRoutine(copy, expectedVersion: nil))
                } label: {
                    DayHopCard {
                        Text(template.name).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("\(template.activeSteps.count) steps").foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pinForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(confirming ? Copy.pinConfirm : Copy.pinTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.pinExplain).foregroundStyle(Theme.muted)
            PinPad(pin: confirming ? $confirm : $pin) { entered in
                if !confirming {
                    if let issue = ParentPin.issue(entered) {
                        message = pinMessage(issue)
                        pin = ""
                    } else {
                        confirming = true
                        message = nil
                    }
                } else if entered != pin {
                    message = Copy.pinMismatchSetup
                    confirm = ""
                    confirming = false
                    pin = ""
                } else if let issue = store.setPIN(entered) {
                    message = pinMessage(issue)
                    confirm = ""
                    confirming = false
                    pin = ""
                }
            }
            if let message { Text(message).foregroundStyle(Theme.ink) }
        }
    }

    private var zones: [String] {
        Array(Set([zone, "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Phoenix", "Pacific/Honolulu"])).sorted()
    }

    private func providerButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold))
                .foregroundStyle(filled ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(filled ? Color.black : Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
        .buttonStyle(.plain)
    }

    private func submitEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains("."), password.count >= 10 else {
            message = Copy.invalidSignIn
            return
        }
        if CloudConfig.load().isConfigured {
            if !reachability.online {
                message = Copy.offlineBlock
                return
            }
            Task { message = signInText(await CloudCenter.shared.signIn(email: trimmed, password: password)) }
            return
        }
        message = signInText(store.signIn(email: trimmed, password: password))
    }

    private func startProvider(_ provider: String) async {
        if CloudConfig.load().isConfigured && !reachability.online {
            message = Copy.offlineBlock
            return
        }
        message = signInText(await CloudCenter.shared.signIn(provider: provider), provider: provider)
    }

    private func signInText(_ issue: SignInIssue?, provider: String? = nil) -> String? {
        switch issue {
        case nil, .cancelled: return nil
        case .invalid: return Copy.invalidSignIn
        case .password: return Copy.wrongPassword
        case .differentHousehold: return Copy.differentHousehold
        case .notConfigured: return provider == "google" ? Copy.providerGoogle : Copy.providerApple
        case .offline: return Copy.offlineBlock
        case .unverified: return Copy.unverifiedGoogle
        case .confirmationSent: return Copy.confirmationSent
        case .alreadyLinked: return Copy.alreadyLinked
        case .useExisting: return Copy.useExisting
        case .generic: return Copy.genericSignIn
        }
    }

    private func saveKid() {
        let result = store.addKid(nickname: nickname, ageBand: age, characterID: characterID, accent: accent)
        kidID = result.id
        switch result.write {
        case .ok: message = nil
        case .duplicate: message = Copy.duplicateName
        case .consent: message = Copy.consentFirst
        case .plan: message = Copy.planLimit
        case .nickname(let issue): message = nicknameMessage(issue)
        case .restoreWindow: message = Copy.restoreTooLate
        }
    }

    private func saveIssue(_ issue: SaveIssue?) -> String? {
        switch issue {
        case nil: return nil
        case .plan: return Copy.planLimit
        case .noSteps: return Copy.zeroSteps
        case .tooMany: return Copy.tooManySteps
        default: return Copy.badText
        }
    }
}

struct PinPad: View {
    @Binding var pin: String
    var onFull: (String) -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "del"]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Theme.ink : Color.clear)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                        .frame(width: 16, height: 16)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pin.count) of 4 digits")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(keys, id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 64)
                    } else {
                        Button {
                            tap(key)
                        } label: {
                            Text(key == "del" ? "⌫" : key)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key == "del" ? "Delete" : key)
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        if key == "del" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < 4 else { return }
        pin.append(key)
        if pin.count == 4 { onFull(pin) }
    }
}

func pinMessage(_ issue: PinIssue) -> String {
    switch issue {
    case .length: return Copy.pinLength
    case .trivial: return Copy.pinTrivial
    case .unavailable: return Copy.pinUnavailable
    }
}

func nicknameMessage(_ issue: NicknameIssue) -> String {
    switch issue {
    case .length: return Copy.nicknameLength
    case .forbidden: return Copy.nicknameForbidden
    case .charset: return Copy.nicknameCharset
    }
}
