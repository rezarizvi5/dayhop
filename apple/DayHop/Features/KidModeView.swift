import LocalAuthentication
import SwiftUI
import UIKit

enum KidRoute: Hashable {
    case play(UUID)
    case rewards
}

struct KidRootView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            KidHomeView()
                .navigationDestination(for: KidRoute.self) { route in
                    switch route {
                    case .play(let id): PlayView(routineID: id)
                    case .rewards: KidRewardsView()
                    }
                }
        }
        .id(store.snapshot.activeKidID)
        .fullScreenCover(item: Binding(get: { store.gate }, set: { store.gate = $0 })) { purpose in
            GateView(purpose: purpose)
        }
    }
}

struct KidHomeView: View {
    @EnvironmentObject private var store: HouseholdStore

    var body: some View {
        let kid = store.snapshot.activeKidID.flatMap { store.kid($0) }
        PaperScreen {
            if let kid {
                home(kid)
            } else {
                picker
            }
        }
        .navigationBarHidden(true)
        .onDisappear { Speaker.stop() }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.chooseKid).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            ForEach(store.activeKids) { kid in
                Button { store.chooseKid(kid.id) } label: {
                    HStack(spacing: 16) {
                        MascotView(characterID: kid.characterID, state: .idle, reduceMotion: true)
                        Text(kid.nickname).font(.title.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kid.nickname)
            }
            grownUps
        }
    }

    private func home(_ kid: Kid) -> some View {
        let today = store.todayString()
        let routines = store.routines(for: kid.id, on: today)
        let unfinished = routines.filter { routine in
            guard let run = store.run(kidID: kid.id, routineID: routine.id, date: today) else { return true }
            return !ApprovalRules.finished.contains(run.status)
        }
        let current = routines.first { routine in
            store.isCurrent(routine) && unfinished.contains { $0.id == routine.id }
        } ?? unfinished.first
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()
                grownUps
            }
            MascotView(characterID: kid.characterID, state: routines.contains { $0.timeOfDay == .evening } && unfinished.isEmpty ? .sleepy : .idle, reduceMotion: false)
            Text(store.greeting(for: kid)).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text("\(Copy.stars(kid.starsBalance)) · \(Copy.streak(kid.streakCurrent))")
                .font(.title3)
                .foregroundStyle(Theme.ink)
            if routines.isEmpty {
                Text(Copy.nothingToday).font(.title2).foregroundStyle(Theme.ink)
            } else if unfinished.isEmpty {
                Text(Copy.allDone).font(.title2).foregroundStyle(Theme.ink)
            }
            ForEach(routines) { routine in
                NavigationLink(value: KidRoute.play(routine.id)) {
                    routineCard(routine, kid: kid, today: today, highlight: routine.id == current?.id)
                }
                .buttonStyle(.plain)
            }
            if store.snapshot.rewards.contains(where: { $0.archivedAt == nil }) || store.snapshot.redemptions.contains(where: { $0.kidID == kid.id }) {
                NavigationLink(value: KidRoute.rewards) {
                    Text(Copy.rewardsShop).font(.title3.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 64)
                }
            }
            if store.activeKids.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Copy.switchKid).font(.headline).foregroundStyle(Theme.ink)
                    ForEach(store.activeKids.filter { $0.id != kid.id }) { other in
                        Button(other.nickname) { store.chooseKid(other.id) }
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button(Copy.chooseKid) { store.beginKidMode() }
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
            }
        }
    }

    private var grownUps: some View {
        Button(Copy.grownUps) { store.gate = .exitKidMode }
            .font(.body.weight(.semibold))
            .frame(minWidth: 64, minHeight: 64)
            .accessibilityHint(Copy.kidModeLock)
    }

    private func routineCard(_ routine: Routine, kid: Kid, today: String, highlight: Bool) -> some View {
        let run = store.run(kidID: kid.id, routineID: routine.id, date: today)
        return DayHopCard {
            Text(routine.name).font(.title.weight(.semibold)).foregroundStyle(Theme.ink)
            if let run, run.status == .pendingApproval { Text(Copy.waitingLine(for: Catalog.character(id: kid.characterID).name)).foregroundStyle(Theme.ink) }
            else if let run, run.status == .completed || run.status == .approved { Text(Copy.finished).foregroundStyle(Theme.muted) }
            else if highlight { Text(Copy.scheduled).foregroundStyle(Color(hex: kid.accent)) }
        }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(highlight ? Color(hex: kid.accent) : Color.clear, lineWidth: 3))
    }
}

struct PlayView: View {
    var routineID: UUID
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var oopsStep: UUID?
    @State private var burst: Burst?
    @State private var busy = false
    @State private var started = Date()

    private struct Burst: Equatable { var final: Bool }

    private var kid: Kid? { store.snapshot.activeKidID.flatMap { store.kid($0) } }
    private var routine: Routine? { store.snapshot.routines.first { $0.id == routineID } }

    var body: some View {
        let today = store.todayString()
        let run = kid.flatMap { store.run(kidID: $0.id, routineID: routineID, date: today) }
        let steps = run?.steps ?? routine?.activeSteps ?? []
        let current = steps.first { step in !(run?.isDone(step.id) ?? false) }
        let finished = run.map { ApprovalRules.finished.contains($0.status) } ?? false
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button(Copy.today) { dismiss() }.font(.title3.weight(.semibold)).frame(minHeight: 64)
                    if let kid { MascotView(characterID: kid.characterID, state: mascotState(routine, finished: finished), reduceMotion: reduceMotion) }
                    Text(routine?.name ?? "").font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
                    if let run, run.routineDate != today {
                        Text(Copy.yesterday).font(.title2)
                        Button(Copy.today) { dismiss() }.frame(minHeight: 64)
                    } else if finished, run?.status == .pendingApproval, let kid {
                        Text(Copy.waitingLine(for: Catalog.character(id: kid.characterID).name)).font(.title2)
                    } else if finished {
                        Text(Copy.finished).font(.title2)
                    } else if run?.status == .reopened {
                        Text(Copy.tryAgain).font(.title2)
                    }
                    if let current, !finished, run?.routineDate ?? today == today {
                        stepCard(current, steps: steps, run: run)
                    }
                    if let message { Text(message).font(.title3).foregroundStyle(Theme.ink) }
                    if let oopsStep, let run, !finished {
                        Button(Copy.oops) { undo(run: run, stepID: oopsStep) }
                            .font(.title2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    if !finished, let run {
                        ForEach(steps.filter { run.isDone($0.id) }) { step in
                            Button("\(Copy.oops) \(step.title)") { undo(run: run, stepID: step.id) }
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                    }
                    dots(steps: steps, run: run)
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            if burst != nil { celebration }
        }
        .navigationBarHidden(true)
        .onAppear { speakCurrent() }
        .onDisappear { Speaker.stop(); burst = nil }
        .onChange(of: current?.id, perform: { _ in
            started = Date()
            speakCurrent()
        })
    }

    private func mascotState(_ routine: Routine?, finished: Bool) -> MascotState {
        if finished { return routine?.timeOfDay == .evening ? .sleepy : .celebrate }
        if routine?.timeOfDay == .evening { return .sleepy }
        return .idle
    }

    private func stepCard(_ step: Step, steps: [Step], run: RoutineRun?) -> some View {
        DayHopCard {
            IconGlyph(key: step.iconKey, size: 72)
            Text(step.title).font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(Copy.stars(step.stars)).font(.title3).foregroundStyle(Theme.muted)
            if let minutes = step.timerMinutes, minutes > 0 { timer(minutes: minutes) }
            Button { finish(step) } label: {
                Text(Copy.done).font(.title.weight(.bold)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 76)
                    .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("\(Copy.done), \(step.title)")
            if kid?.ageBand.preReader == true {
                Button(Copy.readAloud) { Speaker.speak(step.title, enabled: store.snapshot.readAloud) }
                    .frame(minHeight: 64)
            }
        }
    }

    private func timer(minutes: Int) -> some View {
        TimelineView(.periodic(from: started, by: 1)) { context in
            let total = TimeInterval(minutes * 60)
            let left = max(0, total - context.date.timeIntervalSince(started))
            VStack(alignment: .leading) {
                Text(left == 0 ? Copy.timerDone : Copy.timer).font(.headline)
                Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)).font(.title2.monospacedDigit())
            }
            .accessibilityLabel(Copy.timer)
        }
    }

    private func dots(steps: [Step], run: RoutineRun?) -> some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Circle()
                    .fill((run?.isDone(step.id) ?? false) ? Theme.cobalt : Theme.line)
                    .frame(width: 14, height: 14)
                    .accessibilityLabel((run?.isDone(step.id) ?? false) ? "\(step.title) \(Copy.doneDay)" : step.title)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var celebration: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 12) {
                if let kid { MascotView(characterID: kid.characterID, state: burst?.final == true ? .celebrate : .cheer, reduceMotion: reduceMotion) }
                Text(burst?.final == true ? Copy.finished : Copy.nice).font(.largeTitle.weight(.semibold))
                if burst?.final == true, let routine { Text(Copy.bonus(routine.bonusStars)).font(.title2) }
                Button(Copy.skipMoment) { burst = nil }.frame(minHeight: 64)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            Cue.play(burst?.final == true ? "cheer" : "star", enabled: store.snapshot.soundOn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { burst = nil }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func finish(_ step: Step) {
        guard !busy, let kid else { return }
        busy = true
        let outcome = store.completeStep(kidID: kid.id, routineID: routineID, stepID: step.id)
        message = outcomeMessage(outcome)
        if outcome == .ok || outcome == .finishedNow {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Cue.play("tap", enabled: store.snapshot.soundOn)
            oopsStep = step.id
            burst = Burst(final: outcome == .finishedNow)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { if oopsStep == step.id { oopsStep = nil } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { busy = false }
    }

    private func undo(run: RoutineRun, stepID: UUID) {
        let outcome = store.undo(runID: run.id, stepID: stepID)
        message = outcomeMessage(outcome)
        if outcome == .ok { oopsStep = nil }
    }

    private func speakCurrent() {
        guard let kid, kid.ageBand.preReader, store.snapshot.readAloud else { return }
        let today = store.todayString()
        let run = store.run(kidID: kid.id, routineID: routineID, date: today)
        let steps = run?.steps ?? routine?.activeSteps ?? []
        if let current = steps.first(where: { !(run?.isDone($0.id) ?? false) }) {
            Speaker.speak(current.title, enabled: true)
        }
    }

    private func outcomeMessage(_ outcome: StepOutcome) -> String? {
        switch outcome {
        case .ok: return nil
        case .finishedNow: return nil
        case .yesterday: return Copy.yesterday
        case .notToday: return Copy.notToday
        case .missing: return Copy.missing
        case .finished: return Copy.alreadyFinished
        case .invalid: return Copy.badText
        case .starsSpent: return Copy.starsSpent
        }
    }
}

struct KidRewardsView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        let kid = store.snapshot.activeKidID.flatMap { store.kid($0) }
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Button(Copy.today) { dismiss() }.frame(minHeight: 64)
                Text(Copy.rewardsShop).font(.largeTitle.weight(.semibold))
                if let kid { Text(Copy.stars(kid.starsBalance)).font(.title2) }
                let rewards = store.snapshot.rewards.filter { $0.archivedAt == nil }
                if rewards.isEmpty { Text(Copy.noRewards).font(.title3) }
                ForEach(rewards) { reward in
                    DayHopCard {
                        IconGlyph(key: reward.iconKey, size: 48)
                        Text(reward.title).font(.title2.weight(.semibold))
                        Text(Copy.stars(reward.cost)).font(.title3)
                        if let kid, kid.starsBalance < reward.cost {
                            Text(Copy.moreToGo(reward.cost - kid.starsBalance)).font(.title3)
                        } else if store.plusActive {
                            Button(Copy.request) { ask(reward) }
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        } else {
                            Text(Copy.plusAsk).font(.title3)
                        }
                    }
                }
                if let message { Text(message).font(.title3) }
            }
        }
        .navigationBarHidden(true)
    }

    private func ask(_ reward: Reward) {
        guard let kidID = store.snapshot.activeKidID else { return }
        switch store.requestReward(kidID: kidID, rewardID: reward.id) {
        case .ok: message = Copy.waitingShort
        case .needsPlus: message = Copy.plusAsk
        case .missing: message = Copy.missing
        case .weeklyLimit: message = Copy.weeklyLimit
        case .short(let count): message = Copy.moreToGo(count)
        }
    }
}

struct GateView: View {
    var purpose: GatePurpose
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var message: String?
    @State private var replacing = false
    @State private var fresh = ""
    @State private var forgot = false
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(replacing ? Copy.newPIN : Copy.enterPIN).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            if locked { Text(Copy.askGrownUp).font(.title2) }
            PinPad(pin: replacing ? $fresh : $pin) { entered in
                if replacing { setNew(entered) } else { check(entered) }
            }
            .disabled(locked)
            if store.snapshot.faceIDOn && !replacing {
                Button(Copy.useFace) { biometrics() }.frame(minHeight: 44)
            }
            Button(Copy.forgotPIN) { forgot = true }.frame(minHeight: 44)
            if forgot {
                SecureField(Copy.passwordAgain, text: $password).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                Button(Copy.confirmPIN) { reset() }.frame(minHeight: 44)
            }
            if let message { Text(message).foregroundStyle(Theme.ink).multilineTextAlignment(.center) }
            Button(Copy.cancel) { store.gate = nil }.frame(minHeight: 44)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }

    private var locked: Bool {
        ParentPin.isLocked(LockoutState(failures: store.snapshot.pinFailures, lockedUntil: store.snapshot.pinLockedUntil), now: Date())
    }

    private func check(_ entered: String) {
        switch store.checkPIN(entered) {
        case .ok:
            if purpose == .changePIN { replacing = true; pin = ""; message = nil }
            else { succeed() }
        case .mismatch:
            message = Copy.pinMismatch
            pin = ""
        case .locked:
            message = Copy.askGrownUp
            pin = ""
        }
    }

    private func setNew(_ entered: String) {
        if let issue = store.setPIN(entered) {
            message = pinMessage(issue)
            fresh = ""
        } else {
            message = Copy.pinSet
            store.gate = nil
        }
    }

    private func reset() {
        guard store.passwordMatches(password) else { message = Copy.wrongPassword; return }
        replacing = true
        pin = ""
        fresh = ""
        forgot = false
        message = Copy.newPIN
    }

    private func succeed() {
        switch purpose {
        case .exitKidMode: store.exitKidMode()
        case .openParent(let route):
            store.exitKidMode()
            store.pendingRoute = route
        case .signOut: store.signOut()
        case .changePIN: break
        }
        store.gate = nil
    }

    private func biometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            message = Copy.faceUnavailable
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: Copy.enterPIN) { ok, _ in
            DispatchQueue.main.async { if ok { succeed() } }
        }
    }
}
