import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var name = ""
    @State private var zone = ""
    @State private var password = ""
    @State private var message: String?
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section(Copy.householdField) {
                TextField(Copy.householdField, text: $name)
                Picker(Copy.timezone, selection: $zone) {
                    ForEach(zones, id: \.self) { Text($0).tag($0) }
                }
                Button(Copy.save) {
                    if store.setHousehold(name: name, timeZoneID: zone) { message = nil } else { message = Copy.householdName }
                }
                .frame(minHeight: 44)
            }
            Section(Copy.sound) {
                Toggle(Copy.sound, isOn: Binding(get: { store.snapshot.soundOn }, set: { store.setSound($0) }))
                Toggle(Copy.readAloudSetting, isOn: Binding(get: { store.snapshot.readAloud }, set: { store.setReadAloud($0) }))
                Toggle(Copy.faceID, isOn: Binding(get: { store.snapshot.faceIDOn }, set: { store.setFaceID($0) }))
            }
            Section(Copy.quietHours) {
                Stepper("\(Copy.from) \(clock(store.snapshot.quietStartMinute))", value: quietStart, in: 0...(24 * 60 - 30), step: 30)
                Stepper("\(Copy.until) \(clock(store.snapshot.quietEndMinute))", value: quietEnd, in: 0...(24 * 60 - 30), step: 30)
                Text(Copy.quietDefault).font(.footnote).foregroundStyle(Theme.muted)
                Button(Copy.openSettings) { store.openSystemSettings() }.frame(minHeight: 44)
                Text(Copy.notificationsOff).font(.footnote).foregroundStyle(Theme.muted)
            }
            Section {
                NavigationLink(Copy.guardians, value: ParentRoute.invites)
                NavigationLink(Copy.methods, value: ParentRoute.methods)
                NavigationLink(Copy.paywallTitle, value: ParentRoute.paywall)
                NavigationLink(Copy.help, value: ParentRoute.help)
                NavigationLink(Copy.privacy, value: ParentRoute.legal("privacy"))
                NavigationLink(Copy.terms, value: ParentRoute.legal("terms"))
            }
            Section(Copy.share) {
                ShareLink(item: store.exportJSON()) { Text(Copy.exportJSON) }.frame(minHeight: 44)
                ShareLink(item: store.exportCSV()) { Text(Copy.exportCSV) }.frame(minHeight: 44)
                Text(Copy.nothingWaiting).font(.footnote).foregroundStyle(Theme.muted)
            }
            Section {
                Button(Copy.changePIN) { store.gate = .changePIN }.frame(minHeight: 44)
                Button(Copy.signOut) { store.gate = .signOut }.frame(minHeight: 44)
                Text(Copy.signOutBody).font(.footnote).foregroundStyle(Theme.muted)
            }
            Section(Copy.deleteAccount) {
                Text(Copy.deleteAccountBody).font(.footnote).foregroundStyle(Theme.ink)
                Link(Copy.manageSubscription, destination: URL(string: Copy.subscriptionURL)!).frame(minHeight: 44)
                SecureField(Copy.passwordAgain, text: $password)
                Button(Copy.deleteAccount, role: .destructive) { confirmDelete = true }.frame(minHeight: 44)
            }
            Section {
                Text("\(Copy.version) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .foregroundStyle(Theme.muted)
                Text(Copy.syncLater).font(.footnote).foregroundStyle(Theme.muted)
            }
            if let message { Text(message).foregroundStyle(Theme.ink) }
            ForEach(store.snapshot.kids.filter { $0.archivedAt != nil }) { kid in
                Button("\(Copy.restore) \(kid.nickname)") {
                    message = restoreMessage(store.restoreKid(kid.id))
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle(Copy.settings)
        .onAppear {
            name = store.snapshot.householdName
            zone = store.snapshot.timeZoneID
        }
        .confirmationDialog(Copy.deleteAccount, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(Copy.yesDelete, role: .destructive) {
                message = store.deleteAccount(password: password) ? Copy.accountGone : Copy.deletePassword
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: { Text(Copy.deleteAccountBody) }
    }

    private var zones: [String] {
        Array(Set([zone.isEmpty ? TimeZone.current.identifier : zone, "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Phoenix", "Pacific/Honolulu"])).sorted()
    }

    private var quietStart: Binding<Int> {
        Binding(get: { store.snapshot.quietStartMinute }, set: { store.setQuiet(start: $0, end: store.snapshot.quietEndMinute) })
    }

    private var quietEnd: Binding<Int> {
        Binding(get: { store.snapshot.quietEndMinute }, set: { store.setQuiet(start: store.snapshot.quietStartMinute, end: $0) })
    }

    private func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    private func restoreMessage(_ result: KidWrite) -> String {
        switch result {
        case .ok, .duplicate: return Copy.restore
        case .plan: return Copy.planLimit
        case .restoreWindow: return Copy.restoreTooLate
        case .consent, .nickname: return Copy.badText
        }
    }
}

struct InviteView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var code = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text(Copy.inviteHelp)
                Text("\(Copy.owner): \(store.snapshot.email)").foregroundStyle(Theme.muted)
                Text(Copy.leaveNote).font(.footnote)
                Text(Copy.transferNote).font(.footnote)
                Button(Copy.createCode) {
                    message = inviteMessage(store.createInvite())
                }
                .frame(minHeight: 44)
                ForEach(store.snapshot.invites) { invite in
                    VStack(alignment: .leading) {
                        Text(invite.code).font(.title3.monospaced())
                        Text(invite.expiresAt.formatted(date: .abbreviated, time: .omitted)).font(.footnote).foregroundStyle(Theme.muted)
                        if invite.revokedAt == nil && invite.usedAt == nil {
                            Button(Copy.revoke) { store.revokeInvite(invite.id) }.frame(minHeight: 44)
                        }
                    }
                }
            }
            Section(Copy.join) {
                TextField(Copy.code, text: $code).textInputAutocapitalization(.characters)
                Button(Copy.join) { message = inviteMessage(store.lookupInvite(code)) }.frame(minHeight: 44)
                if let message { Text(message) }
            }
        }
        .navigationTitle(Copy.guardians)
    }

    private func inviteMessage(_ result: InviteLookup) -> String {
        switch result {
        case .created: return Copy.createCode
        case .missing: return Copy.inviteMissing
        case .revoked: return Copy.inviteRevoked
        case .used: return Copy.inviteUsed
        case .expired: return Copy.inviteExpired
        case .rate: return Copy.inviteRate
        case .sameDevice: return Copy.inviteSame
        case .limit: return Copy.inviteFull
        }
    }
}

struct MethodsView: View {
    @State private var note: String?

    var body: some View {
        Form {
            Section {
                Text(Copy.methodsBody)
                Label(Copy.email, systemImage: "checkmark.circle.fill")
                Button(Copy.linkApple) { note = Copy.linkUnavailable }.frame(minHeight: 44)
                Button(Copy.linkGoogle) { note = Copy.linkUnavailable }.frame(minHeight: 44)
                Button(Copy.unlink) { note = Copy.cannotUnlink }.frame(minHeight: 44)
                Text(Copy.googleRecovery).font(.footnote).foregroundStyle(Theme.muted)
                if let note { Text(note) }
            }
        }
        .navigationTitle(Copy.methods)
    }
}

struct AddKidView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var age: AgeBand = .seven
    @State private var characterID = "bo"
    @State private var accent = Catalog.accents[1]
    @State private var message: String?

    var body: some View {
        Form {
            TextField(Copy.nickname, text: $nickname)
            Picker(Copy.ageBand, selection: $age) { ForEach(AgeBand.allCases) { Text($0.rawValue).tag($0) } }
            Picker(Copy.character, selection: $characterID) { ForEach(Catalog.characters, id: \.id) { Text($0.name).tag($0.id) } }
            Picker(Copy.colour, selection: $accent) { ForEach(Catalog.accents, id: \.self) { Text($0).tag($0) } }
            if let message { Text(message) }
            Button(Copy.save) { save() }.frame(minHeight: 44)
        }
        .navigationTitle(Copy.addChild)
    }

    private func save() {
        let result = store.addKid(nickname: nickname, ageBand: age, characterID: characterID, accent: accent)
        switch result.write {
        case .ok: dismiss()
        case .duplicate: message = Copy.duplicateName; dismiss()
        case .plan: message = Copy.planLimit
        case .consent: message = Copy.consentFirst
        case .nickname(let issue): message = nicknameMessage(issue)
        case .restoreWindow: message = Copy.restoreTooLate
        }
    }
}

struct KidDetailView: View {
    var kidID: UUID
    @EnvironmentObject private var store: HouseholdStore
    @State private var amount = 1
    @State private var note = ""
    @State private var message: String?
    @State private var visible = 50
    @State private var pauseStart = Date()
    @State private var pauseEnd = Date()
    @State private var confirmDelete = false

    private var kid: Kid? { store.kid(kidID) }

    var body: some View {
        Group {
            if let kid {
                Form {
                    Section {
                        Text("\(Catalog.character(id: kid.characterID).name) · \(Copy.stageName(store.stageMark(for: kid)))")
                        Text(Copy.stars(kid.starsBalance))
                        Text(Copy.streak(kid.streakCurrent))
                        week(kid)
                    }
                    Section(Copy.edit) {
                        ForEach(store.snapshot.routines.filter { $0.kidIDs.contains(kidID) || $0.inactiveKidIDs.contains(kidID) }) { routine in
                            NavigationLink(routine.archivedAt == nil ? routine.name : "\(routine.name) (\(Copy.archived))", value: ParentRoute.editor(routine.id, kidID))
                        }
                        NavigationLink(Copy.addRoutine, value: ParentRoute.editor(nil, kidID))
                    }
                    Section(Copy.adjust) {
                        Stepper("\(Copy.amount): \(amount)", value: $amount, in: -20...20)
                        TextField(Copy.note, text: $note)
                        Button(Copy.save) {
                            switch store.adjustStars(kidID: kidID, amount: amount, note: note) {
                            case nil: message = nil; note = ""
                            case .empty: message = Copy.adjustNeed
                            case .rejected: message = Copy.adjustReject
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    Section(Copy.pause) {
                        DatePicker(Copy.rangeStart, selection: $pauseStart, displayedComponents: .date)
                        DatePicker(Copy.rangeEnd, selection: $pauseEnd, displayedComponents: .date)
                        Button(Copy.pauseSave) {
                            store.addPause(kidID: kidID, start: day(pauseStart), end: day(pauseEnd))
                        }
                        .frame(minHeight: 44)
                    }
                    Section(Copy.ledger) {
                        let rows = store.snapshot.ledger.filter { $0.kidID == kidID }.sorted { $0.createdAt > $1.createdAt }
                        if rows.isEmpty { Text(Copy.emptyLedger) }
                        ForEach(rows.prefix(visible)) { row in
                            VStack(alignment: .leading) {
                                Text("\(row.amount > 0 ? "+" : "")\(row.amount) · \(row.type.rawValue)")
                                if let note = row.note { Text(note).font(.footnote).foregroundStyle(Theme.muted) }
                            }
                            .frame(minHeight: 44)
                        }
                        if rows.count > visible { Button(Copy.loadMore) { visible += 50 }.frame(minHeight: 44) }
                    }
                    Section {
                        Button(Copy.archive) { store.archiveKid(kidID) }.frame(minHeight: 44)
                        Button(Copy.deleteKid, role: .destructive) { confirmDelete = true }.frame(minHeight: 44)
                    }
                    if let message { Text(message) }
                }
                .navigationTitle(kid.nickname)
                .confirmationDialog(Copy.deleteKid, isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(Copy.yesDelete, role: .destructive) { store.deleteKid(kidID) }
                    Button(Copy.cancel, role: .cancel) {}
                } message: {
                    Text(pending ? Copy.pendingWarn : Copy.deleteKidWarn)
                }
            } else {
                Text(Copy.missing).padding()
            }
        }
    }

    private var pending: Bool {
        store.snapshot.runs.contains { $0.kidID == kidID && $0.status == .pendingApproval } || store.snapshot.redemptions.contains { $0.kidID == kidID && $0.status == .requested }
    }

    private func week(_ kid: Kid) -> some View {
        let today = store.todayString()
        let start = Schedule.weekStartMonday(today)
        return HStack {
            ForEach(0..<7, id: \.self) { offset in
                let date = RoutineCalendar.addDays(start, offset)
                let scheduled = !store.routines(for: kid.id, on: date).isEmpty
                let done = store.snapshot.runs.contains { $0.kidID == kid.id && $0.routineDate == date && ($0.status == .approved || $0.status == .completed) }
                VStack {
                    Circle().fill(done ? Theme.cobalt : Color.clear).overlay(Circle().stroke(scheduled ? Theme.ink : Theme.line, lineWidth: 2)).frame(width: 18, height: 18)
                    Text(Schedule.weekdayLabels[offset]).font(.caption2)
                }
                .frame(minWidth: 32, minHeight: 44)
                .accessibilityLabel("\(Schedule.weekdayLabels[offset]) \(done ? Copy.doneDay : scheduled ? Copy.openDay : Copy.restDay)")
            }
        }
    }

    private func day(_ date: Date) -> String { RoutineCalendar.dateString(from: date, timeZone: store.zone) }
}
