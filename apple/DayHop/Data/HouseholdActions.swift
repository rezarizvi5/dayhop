import Foundation

extension HouseholdStore {
    func addKid(nickname: String, ageBand: AgeBand, characterID: String, accent: String) -> KidResult {
        guard snapshot.consentAt != nil else { return KidResult(write: .consent, id: nil) }
        let name = Nicknames.normalize(nickname)
        if let issue = Nicknames.issue(name) { return KidResult(write: .nickname(issue), id: nil) }
        let active = activeKids.count
        if Limits.creationBlocked(plan: snapshot.plan, plusActive: plusActive, kind: "kid", count: active) {
            showPaywall = true
            return KidResult(write: .plan, id: nil)
        }
        let duplicate = activeKids.contains { $0.nickname.compare(name, options: .caseInsensitive) == .orderedSame }
        let kid = Kid(id: UUID(), nickname: name, ageBand: ageBand, characterID: characterID.isEmpty ? Catalog.characters[0].id : characterID, accent: accent, starsBalance: 0, lifetimeStars: 0, streakCurrent: 0, streakBest: 0, createdAt: Date(), archivedAt: nil, pauses: [])
        snapshot.kids.append(kid)
        snapshot.onboardStep = max(snapshot.onboardStep, 6)
        commit()
        return KidResult(write: duplicate ? .duplicate : .ok, id: kid.id)
    }

    func archiveKid(_ id: UUID) {
        guard let index = snapshot.kids.firstIndex(where: { $0.id == id }) else { return }
        snapshot.kids[index].archivedAt = Date()
        for routineIndex in snapshot.routines.indices {
            if let pos = snapshot.routines[routineIndex].kidIDs.firstIndex(of: id) {
                snapshot.routines[routineIndex].kidIDs.remove(at: pos)
                if !snapshot.routines[routineIndex].inactiveKidIDs.contains(id) {
                    snapshot.routines[routineIndex].inactiveKidIDs.append(id)
                }
            }
        }
        if snapshot.activeKidID == id {
            snapshot.activeKidID = nil
            snapshot.kidMode = false
        }
        commit()
    }

    func restoreKid(_ id: UUID) -> KidWrite {
        guard let index = snapshot.kids.firstIndex(where: { $0.id == id }) else { return .consent }
        guard let archived = snapshot.kids[index].archivedAt else { return .ok }
        if Date().timeIntervalSince(archived) > 30 * 24 * 3600 { return .restoreWindow }
        if Limits.creationBlocked(plan: snapshot.plan, plusActive: plusActive, kind: "kid", count: activeKids.count) {
            showPaywall = true
            return .plan
        }
        snapshot.kids[index].archivedAt = nil
        for routineIndex in snapshot.routines.indices {
            if let pos = snapshot.routines[routineIndex].inactiveKidIDs.firstIndex(of: id) {
                snapshot.routines[routineIndex].inactiveKidIDs.remove(at: pos)
                if !snapshot.routines[routineIndex].kidIDs.contains(id) {
                    snapshot.routines[routineIndex].kidIDs.append(id)
                }
            }
        }
        commit()
        return .ok
    }

    func deleteKid(_ id: UUID) {
        snapshot.kids.removeAll { $0.id == id }
        snapshot.runs.removeAll { $0.kidID == id }
        snapshot.redemptions.removeAll { $0.kidID == id }
        snapshot.ledger.removeAll { $0.kidID == id }
        for index in snapshot.routines.indices {
            snapshot.routines[index].kidIDs.removeAll { $0 == id }
            snapshot.routines[index].inactiveKidIDs.removeAll { $0 == id }
        }
        if snapshot.activeKidID == id {
            snapshot.activeKidID = nil
            snapshot.kidMode = false
        }
        commit()
    }

    func addPause(kidID: UUID, start: String, end: String) {
        guard start <= end, let index = snapshot.kids.firstIndex(where: { $0.id == kidID }) else { return }
        snapshot.kids[index].pauses.append(StreakPause(id: UUID(), start: start, end: end))
        refreshDerived()
        commit()
    }

    func saveRoutine(_ draft: Routine, expectedVersion: Int?) -> SaveIssue? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Limits.routineNameLength.contains(name.count), !Nicknames.containsForbidden(name) else { return .name }
        let active = draft.activeSteps
        if active.isEmpty { return .noSteps }
        if active.count > Limits.maxSteps { return .tooMany }
        if !(1...127).contains(draft.days) { return .days }
        if draft.kidIDs.isEmpty { return .kids }
        if !Stars.bonusStarsAllowed(draft.bonusStars) { return .bonus }
        if draft.requiresApproval && !plusActive {
            showPaywall = true
            return .plan
        }
        for step in active {
            let title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !Limits.stepTitleLength.contains(title.count) || Nicknames.containsForbidden(title) { return .step }
            if !Stars.stepStarsAllowed(step.stars) { return .stars }
        }
        if let currentIndex = snapshot.routines.firstIndex(where: { $0.id == draft.id }) {
            if snapshot.routines[currentIndex].version != expectedVersion { return .stale }
            if !plusActive && draft.kidIDs.contains(where: { activeRoutineCount($0) > Limits.limits(for: .free, plusActive: false).routinesPerKid }) {
                return .overLimit
            }
            var next = normalized(draft, name: name)
            next.version = snapshot.routines[currentIndex].version + 1
            next.createdAt = snapshot.routines[currentIndex].createdAt
            snapshot.routines[currentIndex] = next
        } else {
            for kidID in draft.kidIDs where Limits.creationBlocked(plan: snapshot.plan, plusActive: plusActive, kind: "routine", count: activeRoutineCount(kidID)) {
                showPaywall = true
                return .plan
            }
            var next = normalized(draft, name: name)
            next.version = 1
            next.createdAt = Date()
            snapshot.routines.append(next)
            snapshot.createdFirstRoutine = true
            snapshot.onboardStep = max(snapshot.onboardStep, 7)
        }
        commit()
        Task { await rescheduleReminders() }
        return nil
    }

    func archiveRoutine(_ id: UUID) {
        guard let index = snapshot.routines.firstIndex(where: { $0.id == id }) else { return }
        snapshot.routines[index].archivedAt = Date()
        snapshot.reminderRoutineIDs.removeAll { $0 == id }
        commit()
        Task { await rescheduleReminders() }
    }

    func beginKidMode() {
        let kids = activeKids
        guard !kids.isEmpty else { return }
        snapshot.kidMode = true
        snapshot.activeKidID = kids.count == 1 ? kids[0].id : nil
        commit()
    }

    func chooseKid(_ id: UUID) {
        guard activeKids.contains(where: { $0.id == id }) else { return }
        snapshot.kidMode = true
        snapshot.activeKidID = id
        commit()
    }

    func exitKidMode() {
        snapshot.kidMode = false
        commit()
    }

    func completeStep(kidID: UUID, routineID: UUID, stepID: UUID) -> StepOutcome {
        housekeeping()
        let today = todayString()
        guard RoutineCalendar.routineDateAllowed(clientDate: today, serverNow: Date(), timeZone: zone) else { return .yesterday }
        guard let routine = snapshot.routines.first(where: { $0.id == routineID && $0.kidIDs.contains(kidID) && $0.archivedAt == nil }) else { return .missing }
        guard Schedule.isScheduled(routine.days, today) else { return .notToday }
        if let index = snapshot.runs.firstIndex(where: { $0.kidID == kidID && $0.routineID == routineID && $0.routineDate == today }) {
            var run = snapshot.runs[index]
            if run.status == .expired || run.routineDate != today { return .yesterday }
            if ApprovalRules.finished.contains(run.status) { return .finished }
            if run.isDone(stepID) { return .ok }
            guard let step = run.steps.first(where: { $0.id == stepID }), Stars.stepStarsAllowed(step.stars) else { return .invalid }
            return writeCompletion(index: index, run: &run, step: step)
        }
        let steps = routine.activeSteps
        guard let step = steps.first(where: { $0.id == stepID }), Stars.stepStarsAllowed(step.stars) else { return .invalid }
        let needs = routine.requiresApproval && plusActive
        var run = RoutineRun(id: UUID(), kidID: kidID, routineID: routineID, routineDate: today, status: .inProgress, version: routine.version, steps: steps, bonusStars: routine.bonusStars, requiresApproval: needs, completions: [:], submittedAt: nil, autoApproved: false, credited: false)
        snapshot.runs.append(run)
        return writeCompletion(index: snapshot.runs.count - 1, run: &run, step: step)
    }

    func undo(runID: UUID, stepID: UUID) -> StepOutcome {
        guard let index = snapshot.runs.firstIndex(where: { $0.id == runID }) else { return .missing }
        var run = snapshot.runs[index]
        if ApprovalRules.finished.contains(run.status) { return .finished }
        guard var completion = run.completions[stepID], completion.undoneAt == nil else { return .ok }
        guard let step = run.steps.first(where: { $0.id == stepID }) else { return .invalid }
        if !run.requiresApproval && step.stars > 0 {
            let ok = credit(kidID: run.kidID, amount: -step.stars, type: .reversal, key: "undo:\(completion.id.uuidString)")
            if !ok { return .starsSpent }
        }
        completion.undoneAt = Date()
        run.completions[stepID] = completion
        run.status = .inProgress
        snapshot.runs[index] = run
        refreshDerived()
        commit()
        return .ok
    }

    func approve(runID: UUID, reopen: [UUID]) -> String? {
        guard let index = snapshot.runs.firstIndex(where: { $0.id == runID }) else { return "NOT_FOUND" }
        if snapshot.runs[index].status == .approved || snapshot.runs[index].status == .completed { return "ALREADY_HANDLED" }
        approveNow(index: index, reopen: reopen, forceAuto: false)
        commit()
        return nil
    }

    func addReward(title: String, iconKey: String, cost: Int, weeklyLimit: Int?) -> RewardWrite {
        guard plusActive else {
            showPaywall = true
            return .plan
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !Limits.stepTitleLength.contains(name.count) { return .length }
        if Nicknames.containsForbidden(name) { return .forbidden }
        if !Limits.rewardCost.contains(cost) { return .cost }
        if snapshot.rewards.filter({ $0.archivedAt == nil }).count >= Limits.maxActiveRewards { return .limit }
        snapshot.rewards.append(Reward(id: UUID(), title: name, iconKey: iconKey, cost: cost, weeklyLimit: weeklyLimit, archivedAt: nil))
        commit()
        return .ok
    }

    func archiveReward(_ id: UUID) {
        guard let index = snapshot.rewards.firstIndex(where: { $0.id == id }) else { return }
        snapshot.rewards[index].archivedAt = Date()
        commit()
    }

    func requestReward(kidID: UUID, rewardID: UUID) -> RewardOutcome {
        guard plusActive else { return .needsPlus }
        guard let reward = snapshot.rewards.first(where: { $0.id == rewardID && $0.archivedAt == nil }), let kid = kid(kidID) else { return .missing }
        if let limit = reward.weeklyLimit {
            let week = Schedule.weekStartMonday(todayString())
            let count = snapshot.redemptions.filter { item in
                item.rewardID == rewardID && item.kidID == kidID && Schedule.weekStartMonday(RoutineCalendar.routineDate(instant: item.requestedAt, timeZone: zone)) == week
            }.count
            if count >= limit { return .weeklyLimit }
        }
        if kid.starsBalance < reward.cost { return .short(reward.cost - kid.starsBalance) }
        let redemptionID = UUID()
        guard credit(kidID: kidID, amount: -reward.cost, type: .redemptionHold, key: "hold:\(redemptionID.uuidString)") else {
            return .short(reward.cost - kid.starsBalance)
        }
        snapshot.redemptions.append(Redemption(id: redemptionID, kidID: kidID, rewardID: rewardID, title: reward.title, cost: reward.cost, status: .requested, requestedAt: Date(), resolvedAt: nil))
        commit()
        return .ok
    }

    func resolve(redemptionID: UUID, fulfill: Bool) {
        guard let index = snapshot.redemptions.firstIndex(where: { $0.id == redemptionID }), snapshot.redemptions[index].status == .requested else { return }
        let item = snapshot.redemptions[index]
        snapshot.redemptions[index].status = fulfill ? .fulfilled : .denied
        snapshot.redemptions[index].resolvedAt = Date()
        if !fulfill {
            credit(kidID: item.kidID, amount: item.cost, type: .redemptionRefund, key: "refund:\(item.id.uuidString)")
        }
        commit()
    }

    func adjustStars(kidID: UUID, amount: Int, note: String) -> AdjustIssue? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || amount == 0 { return .empty }
        let ok = credit(kidID: kidID, amount: amount, type: .adjustment, key: "adjust:\(UUID().uuidString)", note: String(trimmed.prefix(120)))
        guard ok else { return .rejected }
        commit()
        return nil
    }

    func startLocalTrial(product: String) {
        snapshot.plan = .plus
        snapshot.plusProduct = product
        snapshot.plusExpiresAt = Date().addingTimeInterval(7 * 24 * 3600)
        commit()
    }

    func createInvite() -> InviteLookup {
        let open = snapshot.invites.filter(\.isOpen).count
        if Limits.creationBlocked(plan: snapshot.plan, plusActive: plusActive, kind: "guardian", count: 1 + open) {
            showPaywall = true
            return .limit
        }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<8).compactMap { _ in alphabet.randomElement() })
        snapshot.invites.append(Invite(id: UUID(), code: code, createdAt: Date(), expiresAt: Date().addingTimeInterval(7 * 24 * 3600), revokedAt: nil, usedAt: nil))
        commit()
        return .created
    }

    func revokeInvite(_ id: UUID) {
        guard let index = snapshot.invites.firstIndex(where: { $0.id == id }) else { return }
        snapshot.invites[index].revokedAt = Date()
        commit()
    }

    func lookupInvite(_ code: String) -> InviteLookup {
        let hourAgo = Date().addingTimeInterval(-3600)
        snapshot.inviteFailures.removeAll { $0 < hourAgo }
        if snapshot.inviteFailures.count >= 5 {
            commit()
            return .rate
        }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let invite = snapshot.invites.first(where: { $0.code == normalized }) else {
            snapshot.inviteFailures.append(Date())
            commit()
            return .missing
        }
        if invite.revokedAt != nil { return .revoked }
        if invite.usedAt != nil { return .used }
        if invite.expiresAt < Date() { return .expired }
        return .sameDevice
    }

    private func normalized(_ draft: Routine, name: String) -> Routine {
        var next = draft
        next.name = name
        next.steps = draft.steps.enumerated().map { index, step in
            var copy = step
            copy.position = index
            copy.title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }
        return next
    }

    private func writeCompletion(index: Int, run: inout RoutineRun, step: Step) -> StepOutcome {
        let completion = StepCompletion(id: UUID(), undoneAt: nil)
        run.completions[step.id] = completion
        let doneCount = run.steps.filter { run.isDone($0.id) }.count
        let finished = doneCount == run.steps.count
        let needs = run.requiresApproval && plusActive
        run.requiresApproval = needs
        run.status = finished ? ApprovalRules.statusAfterFinish(requiresApproval: needs, plusActive: plusActive) : .inProgress
        if finished { run.submittedAt = Date() }
        snapshot.runs[index] = run
        if !needs {
            if step.stars > 0 { credit(kidID: run.kidID, amount: step.stars, type: .step, key: "step:\(completion.id.uuidString)") }
            if finished && run.bonusStars > 0 { credit(kidID: run.kidID, amount: run.bonusStars, type: .routineBonus, key: "bonus:\(run.id.uuidString)") }
            if finished { refreshDerived() }
        }
        commit()
        return finished ? .finishedNow : .ok
    }
}
