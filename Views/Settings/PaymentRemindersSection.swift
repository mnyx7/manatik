import SwiftUI

/// The payment reminders list with its add button and editor. Lives in its own
/// view so Settings and the home page's clock open the same thing.
struct PaymentRemindersSection: View {
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            if reminderScheduler.isBlockedInSystemSettings {
                Label(
                    "Notifications are turned off for muna in iOS Settings.",
                    systemImage: "bell.slash"
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.expenseAccent)
            } else if reminderScheduler.needsPermissionPrompt {
                Button {
                    Task {
                        await reminderScheduler.requestAuthorization()
                        await syncReminders()
                    }
                } label: {
                    Label("Allow notifications", systemImage: "bell.badge")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            ForEach(viewModel.reminders) { reminder in
                reminderRow(reminder)
            }
            .onDelete { offsets in
                for index in offsets {
                    guard viewModel.reminders.indices.contains(index) else { continue }
                    viewModel.deleteReminder(viewModel.reminders[index])
                }
                Task { await syncReminders() }
            }

            Button {
                viewModel.addReminder()
            } label: {
                Label("Add a payment reminder", systemImage: "plus.circle")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Payment Reminders")
        } footer: {
            Text("Get a notification before a loan instalment, a utility bill or a subscription is due. Reminders are local to this device.")
        }
        .sheet(isPresented: $viewModel.isShowingReminderEditor) {
            ReminderEditorView(
                reminder: viewModel.editingReminder,
                currency: viewModel.currentCurrency
            ) { saved in
                viewModel.saveReminder(saved)
                Task { await syncReminders() }
            }
        }
    }

    @ViewBuilder
    private func reminderRow(_ reminder: PaymentReminder) -> some View {
        Button {
            viewModel.editReminder(reminder)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(reminderSubtitle(reminder))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { newValue in
                        viewModel.toggleReminder(reminder, isEnabled: newValue)
                        Task { await syncReminders() }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel(Text("Reminder enabled"))
            }
            .frame(minHeight: AppTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }

    private func reminderSubtitle(_ reminder: PaymentReminder) -> String {
        var parts = [DateFormatting.dayMonthYear(reminder.fireDate)]
        if reminder.repeatRule.repeats {
            parts.append(reminder.repeatRule.localizedTitle)
        }
        let money = reminder.localizedSubtitle(currency: viewModel.currentCurrency)
        if !money.isEmpty {
            parts.append(money)
        }
        if reminder.hasLapsed() {
            parts.append(NSLocalizedString("passed", comment: "Reminder state"))
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func syncReminders() async {
        await reminderScheduler.sync(
            reminders: viewModel.store.state.paymentReminders,
            currency: viewModel.currentCurrency
        )
    }
}

/// Reminders on their own page, opened from the clock on an illustrated home.
struct RemindersView: View {
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @State var viewModel: SettingsViewModel

    var body: some View {
        Form {
            PaymentRemindersSection(viewModel: viewModel)
        }
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reminderScheduler.refreshAuthorizationStatus()
        }
    }
}
