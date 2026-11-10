import SwiftUI

struct RoutineEditorView: View {
    var routineID: UUID?
    var kidID: UUID
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Routine(id: UUID(), name: "", timeOfDay: .morning, days: Catalog.weekdayTemplateDays, startTime: nil, requiresApproval: false, bonusStars: 3, version: 1, createdAt: Date(), archivedAt: nil, kidIDs: [], inactiveKidIDs: [], steps: [])
    @State private var expected: Int?
    @State private var loaded = false
    @State private var dirty = false
    @State private var message: String?
    @State private var discard = false
    @State private var iconStep: UUID?
    @State private var showPreview = false
    @State private var remind = false
    @State private var useTime = false
    @State private var clock = Date()

    var body: some View {
        Form {
            Section(Copy.routineName) {
                TextField(Copy.routineName, text: $draft.name)
                    .onChange(of: draft.name, perform: { _ in dirty = true })
            }
            Section(Copy.timeOfDay) {
                Picker(Copy.timeOfDay, selection: $draft.timeOfDay) {
                    Text(Copy.morning).tag(TimeOfDay.morning)
                    Text(Copy.afternoon).tag(TimeOfDay.afternoon)
                    Text(Copy.evening).tag(TimeOfDay.evening)
                    Text(Copy.customTime).tag(TimeOfDay.custom)
                }
            }
            Section(Copy.days) {
                ForEach(Array(Schedule.weekdayLabels.enumerated()), id: \.offset) { index, label in
                    Toggle(label, isOn: dayBinding(Schedule.weekdayBits[index])).frame(minHeight: 44)
                }
            }
            Section(Copy.startTime) {
                Toggle(Copy.startTime, isOn: $useTime).frame(minHeight: 44)
                if useTime {
                    DatePicker(Copy.startTime, selection: $clock, displayedComponents: .hourAndMinute)
                    Text(Copy.reminderNeedsTime).font(.footnote).foregroundStyle(Theme.muted)
                }
                Toggle(Copy.reminderToggle, isOn: $remind).frame(minHeight: 44)
            }
            Section {
                Toggle(Copy.approvalToggle, isOn: approvalBinding).frame(minHeight: 44)
                Stepper("\(Copy.bonusStars): \(draft.bonusStars)", value: $draft.bonusStars, in: 0...10).frame(minHeight: 44)
            }
            Section(Copy.assigned) {
                ForEach(store.snapshot.kids) { kid in
                    if kid.archivedAt == nil || draft.kidIDs.contains(kid.id) || draft.inactiveKidIDs.contains(kid.id) {
                        Toggle(kid.archivedAt == nil ? kid.nickname : "\(kid.nickname) (\(Copy.archived))", isOn: kidBinding(kid))
                            .disabled(kid.archivedAt != nil)
                            .frame(minHeight: 44)
                    }
                }
            }
            Section(Copy.steps) {
                ForEach(draft.activeSteps) { step in
                    stepRow(step)
                }
                .onMove(perform: move)
                Button(Copy.addStep) { addStep() }.frame(minHeight: 44)
            }
            if let message { Text(message).foregroundStyle(Theme.ink) }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(Copy.edit)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(Copy.cancel) { dirty ? (discard = true) : dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button(Copy.save) { save() } }
            ToolbarItem(placement: .primaryAction) { Button(Copy.previewRoutine) { showPreview = true } }
        }
        .onAppear(perform: load)
        .confirmationDialog(Copy.discard, isPresented: $discard, titleVisibility: .visible) {
            Button(Copy.discardYes, role: .destructive) { dismiss() }
            Button(Copy.keepEditing, role: .cancel) {}
        }
        .sheet(isPresented: $showPreview) { preview }
        .sheet(isPresented: Binding(get: { iconStep != nil }, set: { if !$0 { iconStep = nil } })) {
            if let iconStep { IconPicker(selected: iconSelection(iconStep)) }
        }
    }

    private func iconSelection(_ id: UUID) -> Binding<String> {
        Binding(get: { draft.steps.first { $0.id == id }?.iconKey ?? "book" }, set: { newValue in
            if let index = draft.steps.firstIndex(where: { $0.id == id }) {
                draft.steps[index].iconKey = newValue
                dirty = true
            }
        })
    }

    private var approvalBinding: Binding<Bool> {
        Binding(get: { draft.requiresApproval }, set: { on in
            if on && !store.plusActive { store.showPaywall = true; return }
            draft.requiresApproval = on
            dirty = true
        })
    }

    private func dayBinding(_ bit: Int) -> Binding<Bool> {
        Binding(get: { draft.days & bit != 0 }, set: { on in
            draft.days = on ? (draft.days | bit) : (draft.days & ~bit)
            dirty = true
        })
    }

    private func kidBinding(_ kid: Kid) -> Binding<Bool> {
        Binding(get: { draft.kidIDs.contains(kid.id) }, set: { on in
            if on { if !draft.kidIDs.contains(kid.id) { draft.kidIDs.append(kid.id) } }
            else { draft.kidIDs.removeAll { $0 == kid.id } }
            dirty = true
        })
    }

    private func stepRow(_ step: Step) -> some View {
        let index = draft.activeSteps.firstIndex { $0.id == step.id } ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            TextField(Copy.stepTitle, text: titleBinding(step.id))
            HStack {
                Button { iconStep = step.id } label: { IconGlyph(key: step.iconKey, size: 28) }.accessibilityLabel(Copy.icon)
                Stepper("\(Copy.stepStars): \(step.stars)", value: starsBinding(step.id), in: 0...5)
            }
            Stepper("\(Copy.minutes): \(step.timerMinutes ?? 0)", value: timerBinding(step.id), in: 0...60)
            HStack {
                Button(Copy.moveUp) { shift(index, by: -1) }.frame(minHeight: 44)
                Button(Copy.moveDown) { shift(index, by: 1) }.frame(minHeight: 44)
                Button(Copy.delete, role: .destructive) { remove(step.id) }.frame(minHeight: 44)
            }
        }
    }

    private func titleBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { draft.steps.first { $0.id == id }?.title ?? "" }, set: { newValue in
            if let index = draft.steps.firstIndex(where: { $0.id == id }) { draft.steps[index].title = newValue; dirty = true }
        })
    }

    private func starsBinding(_ id: UUID) -> Binding<Int> {
        Binding(get: { draft.steps.first { $0.id == id }?.stars ?? 1 }, set: { newValue in
            if let index = draft.steps.firstIndex(where: { $0.id == id }) { draft.steps[index].stars = newValue; dirty = true }
        })
    }

    private func timerBinding(_ id: UUID) -> Binding<Int> {
        Binding(get: { draft.steps.first { $0.id == id }?.timerMinutes ?? 0 }, set: { newValue in
            if let index = draft.steps.firstIndex(where: { $0.id == id }) { draft.steps[index].timerMinutes = newValue == 0 ? nil : newValue; dirty = true }
        })
    }

    private var preview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(draft.name.isEmpty ? Copy.routineName : draft.name).font(.largeTitle.weight(.semibold))
                ForEach(draft.activeSteps) { step in
                    DayHopCard {
                        IconGlyph(key: step.iconKey, size: 64)
                        Text(step.title).font(.title2.weight(.semibold))
                        Text(Copy.stars(step.stars)).foregroundStyle(Theme.muted)
                    }
                }
                Button(Copy.close) { showPreview = false }.frame(minHeight: 44)
            }
            .padding(24)
        }
        .background(Theme.paper)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let routineID, let existing = store.snapshot.routines.first(where: { $0.id == routineID }) {
            draft = existing
            expected = existing.version
            remind = store.snapshot.reminderRoutineIDs.contains(existing.id)
            if let start = existing.startTime { useTime = true; clock = date(from: start) }
        } else {
            draft.kidIDs = [kidID]
            draft.steps = [Step(id: UUID(), title: "", iconKey: "star", stars: 1, position: 0, timerMinutes: nil, archived: false)]
        }
        dirty = false
    }

    private func save() {
        if useTime {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: clock)
            draft.startTime = String(format: "%02d:%02d", parts.hour ?? 7, parts.minute ?? 0)
        } else {
            draft.startTime = nil
            remind = false
        }
        switch store.saveRoutine(draft, expectedVersion: expected) {
        case nil:
            store.setReminder(draft.id, on: remind)
            dismiss()
        case .name, .step, .stars, .bonus: message = Copy.badText
        case .noSteps: message = Copy.zeroSteps
        case .tooMany: message = Copy.tooManySteps
        case .kids: message = Copy.needKid
        case .days: message = Copy.days
        case .plan: message = Copy.planLimit
        case .stale: message = Copy.stale
        case .overLimit: message = Copy.overLimit
        }
    }

    private func addStep() {
        guard draft.activeSteps.count < Limits.maxSteps else { message = Copy.tooManySteps; return }
        draft.steps.append(Step(id: UUID(), title: "", iconKey: "star", stars: 1, position: draft.steps.count, timerMinutes: nil, archived: false))
        dirty = true
    }

    private func remove(_ id: UUID) {
        guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return }
        if routineID != nil, let existing = store.snapshot.routines.first(where: { $0.id == routineID }), existing.steps.contains(where: { $0.id == id }) {
            draft.steps[index].archived = true
        } else {
            draft.steps.remove(at: index)
        }
        dirty = true
    }

    private func shift(_ index: Int, by delta: Int) {
        var steps = draft.steps.filter { !$0.archived }
        let archived = draft.steps.filter(\.archived)
        let next = index + delta
        guard steps.indices.contains(index), steps.indices.contains(next) else { return }
        steps.swapAt(index, next)
        draft.steps = steps + archived
        dirty = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        var steps = draft.steps.filter { !$0.archived }
        let archived = draft.steps.filter(\.archived)
        steps.move(fromOffsets: source, toOffset: destination)
        draft.steps = steps + archived
        dirty = true
    }

    private func date(from clock: String) -> Date {
        let bits = clock.split(separator: ":")
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        parts.hour = Int(bits.first ?? "7")
        parts.minute = Int(bits.dropFirst().first ?? "0")
        return Calendar.current.date(from: parts) ?? Date()
    }
}
