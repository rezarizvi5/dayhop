import Foundation

extension Notification.Name {
    static let dayhopHouseholdChanged = Notification.Name("dayhop.household.changed")
}

@MainActor
final class CloudCenter {
    static let shared = CloudCenter()

    private let remoteKey = "dayhop.remote.household"
    private let ackedKey = "dayhop.sync.acked"
    private var session: CloudSession?
    private var remoteID: UUID?
    private var acked: Set<String> = []
    private var attempts = 0
    private var failedOps = 0
    private var pushTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private weak var store: HouseholdStore?

    private init() {}

    var providers: [String] {
        let names = session?.identities.map(\.provider) ?? []
        return names.isEmpty ? [] : names
    }

    func attach(_ store: HouseholdStore) {
        self.store = store
        session = KeychainStore.get("cloud-session").flatMap(CloudAuth.decodeSession)
        remoteID = UserDefaults.standard.string(forKey: remoteKey).flatMap(UUID.init)
        acked = Set(UserDefaults.standard.stringArray(forKey: ackedKey) ?? [])
        guard CloudConfig.load().isConfigured, session != nil else { return }
        startLoop()
        Task {
            if let user = UserDefaults.standard.string(forKey: "dayhop.apple.user"),
               await ProviderSignIn.appleCredentialRevoked(user) {
                await self.handleRevoked()
                return
            }
            await self.syncNow()
        }
    }

    private func handleRevoked() async {
        if store?.snapshot.kidMode == true {
            store?.authNotice = Copy.sessionEnded
            store?.gate = .signOut
            return
        }
        store?.signOut()
        store?.authNotice = Copy.sessionEnded
    }

    func foreground() {
        guard CloudConfig.load().isConfigured, session != nil else { return }
        if socket?.state != .running {
            socket?.cancel(with: .goingAway, reason: nil)
            socket = nil
            connectRealtime()
        }
        Task { await self.syncNow() }
    }

    func householdDidChange() {
        guard CloudConfig.load().isConfigured, session != nil, store?.suppressSync == false else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func retry() {
        attempts = 0
        failedOps = 0
        Task { await self.syncNow() }
    }

    func signIn(email: String, password: String) async -> SignInIssue? {
        let config = CloudConfig.load()
        guard config.isConfigured else { return nil }
        switch await CloudAuth.signInWithPassword(config: config, email: email, password: password) {
        case let .success(session):
            return await adopt(session, sampleReset: true)
        case let .failure(error):
            return map(error)
        }
    }

    func signIn(provider: String) async -> SignInIssue? {
        let config = CloudConfig.load()
        guard config.isConfigured else { return .notConfigured }
        if provider == "google" && !config.googleReady { return .notConfigured }
        let credential: Result<ProviderCredential, CloudAuthError>
        if provider == "apple" {
            credential = await ProviderSignIn.apple()
        } else {
            credential = await ProviderSignIn.google(clientID: config.googleClientID, reversedClientID: config.googleReversedClientID)
        }
        switch credential {
        case let .failure(error):
            if error != .cancelled, session != nil, provider == "google", !UserDefaults.standard.bool(forKey: "dayhop.recovery.hint") {
                UserDefaults.standard.set(true, forKey: "dayhop.recovery.hint")
                store?.authNotice = Copy.recoveryHint
            }
            return map(error)
        case let .success(credential):
            switch await CloudAuth.signInWithIDToken(config: config, provider: provider, idToken: credential.idToken, nonce: credential.rawNonce, linking: false) {
            case let .success(session):
                if let appleUserID = credential.appleUserID {
                    UserDefaults.standard.set(appleUserID, forKey: "dayhop.apple.user")
                }
                let issue = await adopt(session, sampleReset: true)
                if issue == nil, provider == "google", store?.snapshot.kids.isEmpty == true {
                    store?.authNotice = Copy.googleEmptyHint
                }
                return issue
            case let .failure(error):
                return map(error)
            }
        }
    }

    func link(provider: String) async -> SignInIssue? {
        guard session != nil else { return .notConfigured }
        let config = CloudConfig.load()
        guard config.isConfigured else { return .notConfigured }
        if provider == "google" && !config.googleReady { return .notConfigured }
        let credential = provider == "apple"
            ? await ProviderSignIn.apple()
            : await ProviderSignIn.google(clientID: config.googleClientID, reversedClientID: config.googleReversedClientID)
        switch credential {
        case let .failure(error):
            return map(error)
        case let .success(credential):
            switch await CloudAuth.signInWithIDToken(config: config, provider: provider, idToken: credential.idToken, nonce: credential.rawNonce, linking: true) {
            case let .success(session):
                save(session)
                return nil
            case let .failure(error):
                return map(error == .useExisting ? .alreadyLinked : error)
            }
        }
    }

    func unlink(provider: String) async -> SignInIssue? {
        guard let session else { return .notConfigured }
        guard CloudRules.canUnlink(identityCount: session.identities.count) else { return .invalid }
        guard let identity = session.identities.first(where: { $0.provider == provider }) else { return .invalid }
        switch await CloudAuth.unlink(config: CloudConfig.load(), session: session, identityID: identity.id) {
        case let .success(next):
            save(next)
            return nil
        case let .failure(error):
            return map(error)
        }
    }

    func reauthenticate(provider: String) async -> Bool {
        guard let current = session else { return false }
        let config = CloudConfig.load()
        let credential = provider == "apple"
            ? await ProviderSignIn.apple()
            : await ProviderSignIn.google(clientID: config.googleClientID, reversedClientID: config.googleReversedClientID)
        guard case let .success(credential) = credential else { return false }
        guard case let .success(next) = await CloudAuth.signInWithIDToken(config: config, provider: provider, idToken: credential.idToken, nonce: credential.rawNonce, linking: false) else { return false }
        guard next.userID == current.userID else { return false }
        save(next)
        return true
    }

    func signOut() async {
        let current = session
        clearLocal()
        if let current { await CloudAuth.signOut(config: CloudConfig.load(), session: current) }
    }

    private func adopt(_ session: CloudSession, sampleReset: Bool) async -> SignInIssue? {
        guard let store else { return .generic }
        if sampleReset, store.snapshot.email == "maya@dayhop.example" {
            store.suppressSync = true
            store.snapshot = HouseholdSnapshot()
            store.suppressSync = false
        }
        if !store.snapshot.email.isEmpty, store.snapshot.email != session.email, !store.snapshot.kids.isEmpty {
            return .differentHousehold
        }
        save(session)
        let serverID = await membershipID(session)
        let decision = CloudRules.join(localRemoteID: remoteID, serverHouseholdID: serverID, localHasContent: !store.snapshot.kids.isEmpty || !store.snapshot.householdName.isEmpty)
        switch decision {
        case .refuseMerge:
            clearLocal()
            return .differentHousehold
        case .useRemote, .alreadySynced:
            guard let serverID, let incoming = await pull(session, householdID: serverID) else {
                failedOps = 1
                publish()
                return .generic
            }
            store.applyCloud(incoming, remoteID: serverID, email: session.email)
            self.remoteID = serverID
            UserDefaults.standard.set(serverID.uuidString, forKey: remoteKey)
            startLoop()
            return nil
        case .uploadLocal:
            let issue = store.noteCloudSignIn(email: session.email)
            startLoop()
            await syncNow()
            return issue
        }
    }

    private func syncNow() async {
        guard let session, let store, CloudConfig.load().isConfigured else { return }
        if session.expiresAt < Date().addingTimeInterval(60) {
            switch await CloudAuth.refresh(config: CloudConfig.load(), session: session) {
            case let .success(next):
                save(next)
            case .failure:
                if store.snapshot.kidMode {
                    store.authNotice = Copy.sessionEnded
                    store.gate = .signOut
                } else {
                    store.signOut()
                    store.authNotice = Copy.sessionEnded
                }
                return
            }
        }
        guard let session = self.session else { return }
        if remoteID == nil {
            remoteID = await membershipID(session)
        }
        if let remoteID {
            await finishPush(session, householdID: remoteID, snapshot: store.snapshot)
        } else if readyToCreate(store.snapshot) {
            if let created = await createHousehold(session, snapshot: store.snapshot) {
                remoteID = created
                UserDefaults.standard.set(created.uuidString, forKey: remoteKey)
                await finishPush(session, householdID: created, snapshot: store.snapshot)
            } else {
                scheduleRetry()
            }
        }
        publish()
    }

    private func finishPush(_ session: CloudSession, householdID: UUID, snapshot: HouseholdSnapshot) async {
        guard await push(session, householdID: householdID, snapshot: snapshot),
              let incoming = await pull(session, householdID: householdID) else {
            scheduleRetry()
            return
        }
        attempts = 0
        failedOps = 0
        store?.applyCloud(incoming, remoteID: householdID, email: session.email)
    }

    private func scheduleRetry() {
        failedOps = max(failedOps, 1)
        attempts += 1
        let delay = CloudRules.retryDelay(attempt: attempts)
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    private func readyToCreate(_ snapshot: HouseholdSnapshot) -> Bool {
        snapshot.signedIn && snapshot.adultConfirmed && !snapshot.householdName.isEmpty && snapshot.email != "maya@dayhop.example"
    }

    private func publish() {
        store?.syncFailedCount = failedOps
    }

    private func save(_ session: CloudSession) {
        self.session = session
        if let raw = CloudAuth.encode(session) {
            KeychainStore.set(raw, account: "cloud-session")
        }
        store?.linkedProviderNames = session.identities.map(\.provider)
    }

    private func clearLocal() {
        session = nil
        remoteID = nil
        KeychainStore.delete("cloud-session")
        UserDefaults.standard.removeObject(forKey: remoteKey)
        UserDefaults.standard.removeObject(forKey: "dayhop.apple.user")
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        pollTask?.cancel()
        pollTask = nil
        store?.linkedProviderNames = []
        store?.syncFailedCount = 0
    }

    private func startLoop() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                await self?.syncNow()
            }
        }
        connectRealtime()
    }

    private func connectRealtime() {
        guard let session, let base = CloudConfig.load().url, socket == nil else { return }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.scheme = base.scheme == "https" ? "wss" : "ws"
        components?.path = "/realtime/v1/websocket"
        components?.queryItems = [URLQueryItem(name: "apikey", value: CloudConfig.load().anonKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        guard let url = components?.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        let join: [String: Any] = [
            "topic": "realtime:household",
            "event": "phx_join",
            "payload": [
                "config": [
                    "postgres_changes": ["kids", "routines", "steps", "routine_assignments", "rewards", "routine_runs", "step_completions", "star_ledger", "redemptions", "invites"].map { table in
                        ["event": "*", "schema": "public", "table": table]
                    },
                ],
                "access_token": session.accessToken,
            ],
            "ref": "1",
        ]
        if let data = try? JSONSerialization.data(withJSONObject: join), let text = String(data: data, encoding: .utf8) {
            task.send(.string(text)) { _ in }
        }
        listen(task)
    }

    private func listen(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case let .success(message) = result {
                    let text: String
                    switch message {
                    case let .string(value): text = value
                    case let .data(value): text = String(data: value, encoding: .utf8) ?? ""
                    @unknown default: text = ""
                    }
                    if text.contains("postgres_changes") {
                        await self.syncNow()
                    }
                    self.listen(task)
                } else {
                    self.socket = nil
                }
            }
        }
    }

    private func membershipID(_ session: CloudSession) async -> UUID? {
        let rows = await select(session, table: "household_members", query: "user_id=eq.\(session.userID.uuidString)&select=household_id")
        return (rows.first?["household_id"] as? String).flatMap(UUID.init)
    }

    private func createHousehold(_ session: CloudSession, snapshot: HouseholdSnapshot) async -> UUID? {
        let result = await rpc(session, name: "create_household", body: ["household_name": snapshot.householdName, "tz": snapshot.timeZoneID])
        if let text = result as? String { return UUID(uuidString: text) }
        return nil
    }

    private func push(_ session: CloudSession, householdID: UUID, snapshot: HouseholdSnapshot) async -> Bool {
        let kids = snapshot.kids.map { kid -> [String: Any] in
            [
                "id": kid.id.uuidString,
                "household_id": householdID.uuidString,
                "nickname": kid.nickname,
                "age_band": kid.ageBand.rawValue,
                "character_id": kid.characterID,
                "accent": kid.accent,
                "streak_current": kid.streakCurrent,
                "streak_best": kid.streakBest,
                "archived_at": kid.archivedAt.map(iso) ?? NSNull(),
            ]
        }
        guard await upsert(session, table: "kids", rows: kids) else { return false }
        var routineRows: [[String: Any]] = []
        var stepRows: [[String: Any]] = []
        var assignmentRows: [[String: Any]] = []
        for routine in snapshot.routines {
            routineRows.append([
                "id": routine.id.uuidString,
                "household_id": householdID.uuidString,
                "name": routine.name,
                "time_of_day": routine.timeOfDay.rawValue,
                "days": routine.days,
                "start_time": sqlTime(routine.startTime),
                "requires_approval": routine.requiresApproval,
                "bonus_stars": routine.bonusStars,
                "version": routine.version,
                "archived_at": routine.archivedAt.map(iso) ?? NSNull(),
            ])
            for step in routine.steps {
                stepRows.append([
                    "id": step.id.uuidString,
                    "routine_id": routine.id.uuidString,
                    "position": step.position,
                    "title": step.title,
                    "icon_key": step.iconKey,
                    "timer_minutes": step.timerMinutes ?? NSNull(),
                    "stars": step.stars,
                    "archived_at": step.archived ? "1970-01-01T00:00:00Z" : NSNull(),
                ])
            }
            for kid in routine.kidIDs {
                assignmentRows.append(["routine_id": routine.id.uuidString, "kid_id": kid.uuidString, "active": true])
            }
            for kid in routine.inactiveKidIDs {
                assignmentRows.append(["routine_id": routine.id.uuidString, "kid_id": kid.uuidString, "active": false])
            }
        }
        guard await upsert(session, table: "routines", rows: routineRows) else { return false }
        guard await upsert(session, table: "steps", rows: stepRows) else { return false }
        guard await upsert(session, table: "routine_assignments", rows: assignmentRows, conflict: "routine_id,kid_id") else { return false }
        let rewards = snapshot.rewards.map { reward -> [String: Any] in
            [
                "id": reward.id.uuidString,
                "household_id": householdID.uuidString,
                "title": reward.title,
                "icon_key": reward.iconKey,
                "cost": reward.cost,
                "weekly_limit": reward.weeklyLimit ?? NSNull(),
                "archived_at": reward.archivedAt.map(iso) ?? NSNull(),
            ]
        }
        guard await upsert(session, table: "rewards", rows: rewards) else { return false }
        for run in snapshot.runs {
            for (stepID, completion) in run.completions where completion.undoneAt == nil && !acked.contains(completion.id.uuidString) {
                let body: [String: Any] = [
                    "completion_id": completion.id.uuidString,
                    "kid_id": run.kidID.uuidString,
                    "routine_id": run.routineID.uuidString,
                    "routine_date": run.routineDate,
                    "step_id": stepID.uuidString,
                    "routine_version": run.version,
                    "snapshot": run.steps.map { ["id": $0.id.uuidString, "title": $0.title, "stars": $0.stars, "position": $0.position] },
                    "client_time": iso(Date()),
                ]
                guard let response = await rpc(session, name: "complete_step", body: body) as? [String: Any] else { return false }
                if let error = response["error"] as? String, error != "ALREADY_HANDLED" {
                    if ["FORBIDDEN", "NOT_FOUND", "INVALID_DATE"].contains(error) { failedOps += 1 }
                    else { return false }
                } else {
                    acked.insert(completion.id.uuidString)
                }
            }
        }
        UserDefaults.standard.set(Array(acked.prefix(5000)), forKey: ackedKey)
        return true
    }

    private func pull(_ session: CloudSession, householdID: UUID) async -> HouseholdSnapshot? {
        let households = await select(session, table: "households", query: "id=eq.\(householdID.uuidString)")
        guard let house = households.first else { return nil }
        var snapshot = HouseholdSnapshot()
        snapshot.householdName = house["name"] as? String ?? ""
        snapshot.timeZoneID = house["timezone"] as? String ?? TimeZone.current.identifier
        snapshot.plan = PlanID(rawValue: house["plan"] as? String ?? "free") ?? .free
        snapshot.plusExpiresAt = date(house["plus_expires_at"])
        snapshot.kids = await select(session, table: "kids", query: "household_id=eq.\(householdID.uuidString)&deleted_at=is.null").map(kid)
        let routineRows = await select(session, table: "routines", query: "household_id=eq.\(householdID.uuidString)")
        let routineIDs = routineRows.compactMap { $0["id"] as? String }.joined(separator: ",")
        let stepRows = routineIDs.isEmpty ? [] : await select(session, table: "steps", query: "routine_id=in.(\(routineIDs))")
        let assignmentRows = routineIDs.isEmpty ? [] : await select(session, table: "routine_assignments", query: "routine_id=in.(\(routineIDs))")
        snapshot.routines = routineRows.map { row in routine(row, steps: stepRows, assignments: assignmentRows) }
        snapshot.rewards = await select(session, table: "rewards", query: "household_id=eq.\(householdID.uuidString)").map(reward)
        var runs: [RoutineRun] = []
        for row in await select(session, table: "routine_runs", query: "household_id=eq.\(householdID.uuidString)") {
            let completions = await select(session, table: "step_completions", query: "run_id=eq.\(row["id"] as? String ?? "")")
            runs.append(run(row, completions: completions))
        }
        snapshot.runs = runs
        snapshot.ledger = await select(session, table: "star_ledger", query: "household_id=eq.\(householdID.uuidString)").map(ledger)
        snapshot.redemptions = await select(session, table: "redemptions", query: "household_id=eq.\(householdID.uuidString)").compactMap(redemption)
        let consents = await select(session, table: "consents", query: "household_id=eq.\(householdID.uuidString)")
        snapshot.consentAt = consents.compactMap { date($0["consented_at"]) }.max() ?? Date()
        snapshot.policyVersion = consents.last?["policy_version"] as? String ?? snapshot.policyVersion
        snapshot.adultConfirmed = true
        snapshot.signedIn = true
        return snapshot
    }

    private func kid(_ row: [String: Any]) -> Kid {
        Kid(
            id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
            nickname: row["nickname"] as? String ?? "",
            ageBand: AgeBand(rawValue: row["age_band"] as? String ?? "") ?? .five,
            characterID: row["character_id"] as? String ?? "pip",
            accent: row["accent"] as? String ?? "#2457d6",
            starsBalance: number(row["stars_balance"]),
            lifetimeStars: number(row["lifetime_stars"]),
            streakCurrent: number(row["streak_current"]),
            streakBest: number(row["streak_best"]),
            createdAt: date(row["created_at"]) ?? Date(),
            archivedAt: date(row["archived_at"]),
            pauses: []
        )
    }

    private func routine(_ row: [String: Any], steps stepRows: [[String: Any]], assignments: [[String: Any]]) -> Routine {
        let id = row["id"] as? String ?? ""
        let steps = stepRows.filter { $0["routine_id"] as? String == id }.map { step -> Step in
            Step(
                id: UUID(uuidString: step["id"] as? String ?? "") ?? UUID(),
                title: step["title"] as? String ?? "",
                iconKey: step["icon_key"] as? String ?? "star",
                stars: number(step["stars"], fallback: 1),
                position: number(step["position"]),
                timerMinutes: optionalNumber(step["timer_minutes"]),
                archived: step["archived_at"] != nil && !(step["archived_at"] is NSNull)
            )
        }
        let links = assignments.filter { $0["routine_id"] as? String == id }
        return Routine(
            id: UUID(uuidString: id) ?? UUID(),
            name: row["name"] as? String ?? "",
            timeOfDay: TimeOfDay(rawValue: row["time_of_day"] as? String ?? "") ?? .morning,
            days: number(row["days"], fallback: 127),
            startTime: clock(row["start_time"]),
            requiresApproval: flag(row["requires_approval"]),
            bonusStars: number(row["bonus_stars"], fallback: 3),
            version: number(row["version"], fallback: 1),
            createdAt: date(row["created_at"]) ?? Date(),
            archivedAt: date(row["archived_at"]),
            kidIDs: links.filter { $0["active"] as? Bool != false }.compactMap { UUID(uuidString: $0["kid_id"] as? String ?? "") },
            inactiveKidIDs: links.filter { $0["active"] as? Bool == false }.compactMap { UUID(uuidString: $0["kid_id"] as? String ?? "") },
            steps: steps
        )
    }

    private func reward(_ row: [String: Any]) -> Reward {
        Reward(
            id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
            title: row["title"] as? String ?? "",
            iconKey: row["icon_key"] as? String ?? "star",
            cost: number(row["cost"], fallback: 1),
            weeklyLimit: optionalNumber(row["weekly_limit"]),
            archivedAt: date(row["archived_at"])
        )
    }

    private func run(_ row: [String: Any], completions rows: [[String: Any]]) -> RoutineRun {
        var completions: [UUID: StepCompletion] = [:]
        for item in rows {
            guard let step = UUID(uuidString: item["step_id"] as? String ?? ""), let id = UUID(uuidString: item["id"] as? String ?? "") else { continue }
            completions[step] = StepCompletion(id: id, undoneAt: date(item["undone_at"]))
        }
        let status = RunStatus(rawValue: row["status"] as? String ?? "") ?? .inProgress
        return RoutineRun(
            id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
            kidID: UUID(uuidString: row["kid_id"] as? String ?? "") ?? UUID(),
            routineID: UUID(uuidString: row["routine_id"] as? String ?? "") ?? UUID(),
            routineDate: String((row["routine_date"] as? String ?? "").prefix(10)),
            status: status,
            version: number(row["routine_version"], fallback: 1),
            steps: [],
            bonusStars: 3,
            requiresApproval: status == .pendingApproval,
            completions: completions,
            submittedAt: date(row["submitted_at"]),
            autoApproved: flag(row["auto_approved"]),
            credited: status == .approved || status == .completed
        )
    }

    private func ledger(_ row: [String: Any]) -> LedgerRow {
        LedgerRow(
            id: row["id"] as? String ?? UUID().uuidString,
            kidID: UUID(uuidString: row["kid_id"] as? String ?? "") ?? UUID(),
            amount: number(row["amount"]),
            type: LedgerType(rawValue: row["type"] as? String ?? "") ?? .adjustment,
            note: row["note"] as? String,
            createdAt: date(row["created_at"]) ?? Date()
        )
    }

    private func redemption(_ row: [String: Any]) -> Redemption? {
        guard let id = UUID(uuidString: row["id"] as? String ?? ""),
              let kid = UUID(uuidString: row["kid_id"] as? String ?? ""),
              let status = RedemptionStatus(rawValue: row["status"] as? String ?? "") else { return nil }
        return Redemption(
            id: id,
            kidID: kid,
            rewardID: UUID(uuidString: row["reward_id"] as? String ?? "") ?? id,
            title: row["reward_title"] as? String ?? "",
            cost: number(row["cost"]),
            status: status,
            requestedAt: date(row["requested_at"]) ?? Date(),
            resolvedAt: date(row["resolved_at"])
        )
    }

    private func select(_ session: CloudSession, table: String, query: String) async -> [[String: Any]] {
        guard let base = CloudConfig.load().url else { return [] }
        var components = URLComponents(url: base.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.query = query
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        authorize(&request, session: session)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        } catch {
            return []
        }
    }

    private func upsert(_ session: CloudSession, table: String, rows: [[String: Any]], conflict: String = "id") async -> Bool {
        if rows.isEmpty { return true }
        guard let base = CloudConfig.load().url else { return false }
        var components = URLComponents(url: base.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.query = "on_conflict=\(conflict)"
        var request = URLRequest(url: components?.url ?? base)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: rows)
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        authorize(&request, session: session)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func rpc(_ session: CloudSession, name: String, body: [String: Any]) async -> Any? {
        guard let base = CloudConfig.load().url else { return nil }
        var request = URLRequest(url: base.appendingPathComponent("rest/v1/rpc/\(name)"))
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        authorize(&request, session: session)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try? JSONSerialization.jsonObject(with: data)
        } catch {
            return nil
        }
    }

    private func authorize(_ request: inout URLRequest, session: CloudSession) {
        let config = CloudConfig.load()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    }

    private func sqlTime(_ value: String?) -> Any {
        guard let value, !value.isEmpty else { return NSNull() }
        return value.count == 5 ? value + ":00" : value
    }

    private func clock(_ value: Any?) -> String? {
        guard let text = value as? String, text.count >= 5 else { return nil }
        return String(text.prefix(5))
    }

    private func number(_ value: Any?, fallback: Int = 0) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String, let parsed = Int(value) { return parsed }
        return fallback
    }

    private func optionalNumber(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        return number(value)
    }

    private func flag(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text) ?? formatter.date(from: String(text.prefix(19)) + "Z")
    }

    private func map(_ error: CloudAuthError) -> SignInIssue {
        switch error {
        case .notConfigured: return .notConfigured
        case .offline: return .offline
        case .cancelled: return .cancelled
        case .unverified: return .unverified
        case .confirmationSent: return .confirmationSent
        case .invalid: return .invalid
        case .password: return .password
        case .alreadyLinked: return .alreadyLinked
        case .useExisting: return .useExisting
        case .generic: return .generic
        case .differentHousehold: return .differentHousehold
        }
    }
}
