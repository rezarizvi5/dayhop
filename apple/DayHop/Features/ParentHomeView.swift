import SwiftUI

struct ParentRootView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var path: [ParentRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ParentHomeView(path: $path)
                .navigationDestination(for: ParentRoute.self) { route in
                    switch route {
                    case .inbox: InboxView()
                    case .rewards: RewardsView()
                    case .settings: SettingsView()
                    case .paywall: PaywallView()
                    case .summary: SummaryView()
                    case .help: HelpView()
                    case .invites: InviteView()
                    case .methods: MethodsView()
                    case .addKid: AddKidView()
                    case .legal(let kind): LegalView(kind: kind)
                    case .kid(let id): KidDetailView(kidID: id)
                    case .editor(let routineID, let kidID): RoutineEditorView(routineID: routineID, kidID: kidID)
                    }
                }
        }
        .sheet(isPresented: paywallBinding) { NavigationStack { PaywallView() } }
        .sheet(isPresented: reminderBinding) { reminderSheet }
        .onAppear(perform: consume)
        .onChange(of: store.pendingRoute, perform: { _ in consume() })
    }

    private var paywallBinding: Binding<Bool> {
        Binding(get: { store.showPaywall }, set: { store.showPaywall = $0 })
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { store.askForReminders }, set: { store.askForReminders = $0 })
    }

    private var reminderSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.remindersAsk).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            PrimaryButton(title: Copy.allowReminders) { Task { await store.allowReminders() } }
            SecondaryButton(title: Copy.notNow) { store.declineReminderPrompt() }
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func consume() {
        guard let route = store.pendingRoute else { return }
        path = [route]
        store.pendingRoute = nil
    }
}

struct ParentHomeView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Binding var path: [ParentRoute]

    var body: some View {
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.snapshot.householdName.isEmpty ? Copy.appName : store.snapshot.householdName)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Copy.savedOnDevice) · \(store.todayString())")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                if store.syncFailedCount > 0 {
                    Text(Copy.syncFailed(store.syncFailedCount)).foregroundStyle(Theme.ink)
                    Button(Copy.syncRetry) { CloudCenter.shared.retry() }.frame(minHeight: 44)
                } else if !CloudConfig.load().isConfigured {
                    Text(Copy.syncLater).font(.subheadline).foregroundStyle(Theme.muted)
                }
                if let notice = store.authNotice {
                    Text(notice).foregroundStyle(Theme.ink)
                    Button(Copy.done) { store.authNotice = nil }.frame(minHeight: 44)
                }
                if store.deviceZoneDiffers {
                    DayHopCard {
                        Text(Copy.zoneBanner).foregroundStyle(Theme.ink)
                        Button(Copy.keepZone) { store.dismissZone() }.frame(minHeight: 44)
                        Button(Copy.useZone) { store.adoptDeviceZone() }.frame(minHeight: 44)
                    }
                }
                if store.overFreeLimit { Text(Copy.lapse).foregroundStyle(Theme.ink) }
                if store.snapshot.balanceCapped {
                    Button(Copy.capped) { store.dismissCap() }.frame(minHeight: 44)
                }
                let waiting = store.pendingRuns.count + store.pendingRewards.count
                if waiting > 0 {
                    Button { path.append(.inbox) } label: {
                        DayHopCard {
                            Text("\(store.pendingRuns.count) runs waiting. \(store.pendingRewards.count) reward requests.")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(waiting) waiting")
                }
                if store.activeKids.isEmpty {
                    Text(Copy.kidsEmpty).foregroundStyle(Theme.ink)
                }
                ForEach(store.activeKids) { kid in
                    Button { path.append(.kid(kid.id)) } label: { kidCard(kid) }
                        .buttonStyle(.plain)
                }
                PrimaryButton(title: Copy.startKid) { store.beginKidMode() }
                    .disabled(store.activeKids.isEmpty)
                SecondaryButton(title: Copy.addRoutine) {
                    if let kid = store.activeKids.first { path.append(.editor(nil, kid.id)) }
                }
                SecondaryButton(title: Copy.approvals) { path.append(.inbox) }
                SecondaryButton(title: Copy.rewards) { path.append(.rewards) }
                SecondaryButton(title: Copy.thisWeek) { path.append(.summary) }
                SecondaryButton(title: Copy.settings) { path.append(.settings) }
                SecondaryButton(title: Copy.addChild) { path.append(.addKid) }
            }
        }
        .navigationBarHidden(true)
    }

    private func kidCard(_ kid: Kid) -> some View {
        let today = store.todayString()
        let routines = store.routines(for: kid.id, on: today)
        let done = routines.filter { routine in
            guard let run = store.run(kidID: kid.id, routineID: routine.id, date: today) else { return false }
            return run.status == .completed || run.status == .approved || run.status == .pendingApproval
        }.count
        let progress = routines.isEmpty ? 0 : Double(done) / Double(routines.count)
        return DayHopCard {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 8)
                    Circle().trim(from: 0, to: progress)
                        .stroke(Color(hex: kid.accent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(Catalog.character(id: kid.characterID).name.prefix(1))
                        .font(.headline)
                        .foregroundStyle(Color(hex: kid.accent))
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kid.nickname).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("\(Catalog.character(id: kid.characterID).name) · \(Copy.stars(kid.starsBalance)) · \(Copy.streak(kid.streakCurrent))")
                        .foregroundStyle(Theme.ink)
                    Text(Copy.progress(done: done, total: routines.count)).foregroundStyle(Theme.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InboxView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var reopen: [UUID: Set<UUID>] = [:]

    var body: some View {
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text(Copy.approvals).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
                if store.pendingRuns.isEmpty && store.pendingRewards.isEmpty {
                    Text(Copy.emptyInbox).foregroundStyle(Theme.ink)
                }
                ForEach(store.pendingRuns) { run in
                    DayHopCard {
                        Text(title(run)).font(.headline).foregroundStyle(Theme.ink)
                        if run.autoApproved { Text(Copy.autoApproved).foregroundStyle(Theme.muted) }
                        ForEach(run.steps) { step in
                            Toggle(step.title, isOn: binding(run: run.id, step: step.id))
                                .frame(minHeight: 44)
                        }
                        Text(Copy.reopenHint).font(.subheadline).foregroundStyle(Theme.muted)
                        PrimaryButton(title: Copy.approveAll) { _ = store.approve(runID: run.id, reopen: []) }
                        SecondaryButton(title: Copy.sendBack) {
                            _ = store.approve(runID: run.id, reopen: Array(reopen[run.id] ?? []))
                        }
                    }
                }
                ForEach(store.pendingRewards) { item in
                    DayHopCard {
                        Text(item.title).font(.headline).foregroundStyle(Theme.ink)
                        Text(Copy.stars(item.cost)).foregroundStyle(Theme.muted)
                        PrimaryButton(title: Copy.fulfil) { store.resolve(redemptionID: item.id, fulfill: true) }
                        SecondaryButton(title: Copy.deny) { store.resolve(redemptionID: item.id, fulfill: false) }
                    }
                }
            }
        }
        .navigationTitle(Copy.approvals)
    }

    private func title(_ run: RoutineRun) -> String {
        let kid = store.kid(run.kidID)?.nickname ?? ""
        let name = store.snapshot.routines.first { $0.id == run.routineID }?.name ?? ""
        return "\(kid) · \(name)"
    }

    private func binding(run: UUID, step: UUID) -> Binding<Bool> {
        Binding(get: { reopen[run]?.contains(step) ?? false }, set: { on in
            var set = reopen[run] ?? []
            if on { set.insert(step) } else { set.remove(step) }
            reopen[run] = set
        })
    }
}

struct RewardsView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var title = ""
    @State private var cost = 5
    @State private var limit = 0
    @State private var icon = "book"
    @State private var message: String?
    @State private var picking = false

    var body: some View {
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text(Copy.rewards).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
                if !store.plusActive { Text(Copy.requiresPlus).foregroundStyle(Theme.ink) }
                ForEach(store.snapshot.rewards) { reward in
                    DayHopCard {
                        HStack {
                            IconGlyph(key: reward.iconKey, size: 28)
                            VStack(alignment: .leading) {
                                Text(reward.title).foregroundStyle(Theme.ink)
                                Text(Copy.stars(reward.cost)).foregroundStyle(Theme.muted)
                                if reward.archivedAt != nil { Text(Copy.archived).foregroundStyle(Theme.muted) }
                            }
                        }
                        if reward.archivedAt == nil {
                            Button(Copy.archive) { store.archiveReward(reward.id) }.frame(minHeight: 44)
                        }
                    }
                }
                TextField(Copy.rewardTitle, text: $title).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                Stepper("\(Copy.cost): \(cost)", value: $cost, in: 1...999).frame(minHeight: 44)
                Stepper("\(Copy.weeklyCap): \(limit == 0 ? Copy.none : String(limit))", value: $limit, in: 0...14).frame(minHeight: 44)
                Button { picking = true } label: { Label(Copy.icon, systemImage: IconCatalog.symbol(for: icon)) }.frame(minHeight: 44)
                if let message { Text(message).foregroundStyle(Theme.ink) }
                PrimaryButton(title: Copy.addReward) { add() }
            }
        }
        .navigationTitle(Copy.rewards)
        .sheet(isPresented: $picking) { IconPicker(selected: $icon) }
    }

    private func add() {
        switch store.addReward(title: title, iconKey: icon, cost: cost, weeklyLimit: limit == 0 ? nil : limit) {
        case .ok: message = nil; title = ""
        case .plan: message = Copy.planLimit
        case .cost: message = Copy.rewardCostRange
        case .length: message = Copy.rewardLength
        case .limit: message = Copy.rewardMax
        case .forbidden: message = Copy.badText
        }
    }
}

struct IconPicker: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(IconCatalog.search(query)) { icon in
                Button {
                    selected = icon.key
                    dismiss()
                } label: {
                    Label(icon.words, systemImage: IconCatalog.symbol(for: icon.key))
                        .frame(minHeight: 44)
                }
            }
            .searchable(text: $query, prompt: Copy.searchIcons)
            .navigationTitle(Copy.icon)
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var note: String?
    @State private var legal: String?

    var body: some View {
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text(Copy.paywallTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(Copy.monthly).font(.title3.weight(.semibold))
                Text(Copy.annual).font(.title3.weight(.semibold))
                Text(Copy.trial).foregroundStyle(Theme.ink)
                Text(Copy.billing).foregroundStyle(Theme.ink)
                Text(Copy.localTrial).foregroundStyle(Theme.muted)
                Text(Copy.freeNote).foregroundStyle(Theme.muted)
                PrimaryButton(title: "\(Copy.startTrial) · \(Copy.monthly)") { store.startLocalTrial(product: "monthly") }
                SecondaryButton(title: "\(Copy.startTrial) · \(Copy.annual)") { store.startLocalTrial(product: "annual") }
                Button(Copy.restorePurchases) { note = Copy.restoreNote }.frame(minHeight: 44)
                Link(Copy.manageSubscription, destination: URL(string: Copy.subscriptionURL)!)
                    .frame(minHeight: 44)
                Button(Copy.privacy) { legal = "privacy" }.frame(minHeight: 44)
                Button(Copy.terms) { legal = "terms" }.frame(minHeight: 44)
                if let note { Text(note).foregroundStyle(Theme.ink) }
                if store.plusActive {
                    Text("\(Copy.onDevice): \(store.snapshot.plusProduct ?? Copy.trial)").foregroundStyle(Theme.muted)
                }
            }
        }
        .navigationTitle(Copy.paywallTitle)
        .sheet(isPresented: Binding(get: { legal != nil }, set: { if !$0 { legal = nil } })) {
            LegalView(kind: legal ?? "privacy")
        }
    }
}

struct SummaryView: View {
    @EnvironmentObject private var store: HouseholdStore

    var body: some View {
        PaperScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.plusActive ? Copy.fullWeek : Copy.basicWeek).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(store.weekStats(for: store.activeKids.first ?? store.snapshot.kids.first ?? placeholder).summaryReady ? Copy.ready : Copy.sunday)
                    .foregroundStyle(Theme.muted)
                ForEach(store.snapshot.kids.filter { $0.archivedAt == nil }) { kid in
                    let stats = store.weekStats(for: kid)
                    DayHopCard {
                        Text(kid.nickname).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        if stats.scheduledDays == 0 {
                            Text(Copy.emptyWeek).foregroundStyle(Theme.ink)
                        } else {
                            Text(Copy.finishedDays(stats.completedDays, stats.scheduledDays)).foregroundStyle(Theme.ink)
                            Text("\(Copy.earned): \(Copy.stars(stats.starsEarned))").foregroundStyle(Theme.ink)
                        }
                        if store.plusActive {
                            if let best = stats.bestRoutine { Text("\(Copy.best): \(best)").foregroundStyle(Theme.ink) }
                            Text("\(Copy.spent): \(Copy.stars(stats.starsSpent))").foregroundStyle(Theme.ink)
                            Text("\(Copy.streakLabel): \(Copy.streak(stats.streak))").foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
        }
        .navigationTitle(Copy.thisWeek)
    }

    private var placeholder: Kid {
        Kid(id: UUID(), nickname: "", ageBand: .five, characterID: "pip", accent: Catalog.accents[0], starsBalance: 0, lifetimeStars: 0, streakCurrent: 0, streakBest: 0, createdAt: Date(), archivedAt: nil, pauses: [])
    }
}

struct LegalView: View {
    var kind: String

    var body: some View {
        PaperScreen {
            Text(kind == "privacy" ? Copy.privacy : Copy.terms).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(kind == "privacy" ? Copy.legalPrivacy : Copy.legalTerms).foregroundStyle(Theme.ink).padding(.top, 12)
        }
        .navigationTitle(kind == "privacy" ? Copy.privacy : Copy.terms)
    }
}

struct HelpView: View {
    var body: some View {
        PaperScreen {
            Text(Copy.guidedTitle).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(Copy.guidedBody).foregroundStyle(Theme.ink).padding(.top, 12)
            Link(Copy.support, destination: URL(string: "mailto:\(Copy.contact)")!).padding(.top, 12).frame(minHeight: 44)
        }
        .navigationTitle(Copy.help)
    }
}
