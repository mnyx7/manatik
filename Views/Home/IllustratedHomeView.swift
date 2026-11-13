//
//  IllustratedHomeView.swift
//  muna
//
//  Created by Minaya Yagubova on 11.11.26.
//

import SwiftUI

/// The illustrated home pages: a picture of a room whose shelf objects are the
/// app's sections.
///
/// The scenery (wall, girl, cat, tree) is one image. Everything that shows a
/// number or opens a screen is drawn natively on top, at fixed spots on a
/// 1080-wide design canvas scaled to the screen, so the figures are live, the
/// tap targets are real buttons, and VoiceOver can read each one.
struct IllustratedHomeView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel
    let style: HomeStyle

    let onOpenActivities: (ActivityScope) -> Void
    let onOpenOverview: () -> Void
    let onOpenSavings: () -> Void
    let onOpenLoans: () -> Void
    let onOpenReminders: () -> Void

    private let recentLimit = 4

    private var family: HomeStyle.Family { style.family ?? .cozy }
    private var palette: HomePalette { HomePalette(family) }
    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    scene(width: geometry.size.width)
                    belowTheShelves
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        }
        .background {
            VStack(spacing: 0) {
                palette.wall
                palette.floor
            }
            .ignoresSafeArea()
        }
        // The room is painted in daylight colours, so its controls stay in
        // light appearance even when the rest of the app is dark.
        .environment(\.colorScheme, .light)
        .navigationTitle(DateRangeCalculator.periodDisplayText(for: period))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PeriodToolbar(store: store, viewModel: viewModel) }
    }

    // MARK: - The room

    private func scene(width: CGFloat) -> some View {
        let s = width / HomeCanvas.width

        return ZStack(alignment: .topLeading) {
            if let name = style.backgroundImageName {
                Image(name)
                    .resizable()
                    .frame(width: width, height: HomeCanvas.height * s)
                    .accessibilityHidden(true)
            }

            objectButton(label: balanceAccessibility, action: onOpenOverview) {
                BalanceObject(family: family, s: s, greeting: greeting, amount: balanceText, caption: balanceCaption)
            }
            .place(HomeCanvas.balance, s)

            objectButton(label: bookAccessibility("Expenses", summary.expense), action: { onOpenActivities(.expense) }) {
                BookObject(
                    family: family, s: s, title: "Expenses",
                    value: whole(summary.expense), symbol: "bag",
                    fill: palette.expenses, onFill: palette.textOnStrong
                )
            }
            .place(HomeCanvas.expenses, s)

            objectButton(label: bookAccessibility("Income", summary.income), action: { onOpenActivities(.income) }) {
                BookObject(
                    family: family, s: s, title: "Income",
                    value: whole(summary.income), symbol: "arrow.down.to.line",
                    fill: palette.income, onFill: palette.textOnSoft
                )
            }
            .place(HomeCanvas.income, s)

            objectButton(label: billsAccessibility, action: { onOpenActivities(.bills) }) {
                BookObject(
                    family: family, s: s, title: "Bills",
                    value: billsValue, symbol: "envelope",
                    fill: palette.bills, onFill: palette.textOnSoft,
                    badge: billsCount > 0 ? billsCount : nil
                )
            }
            .place(HomeCanvas.bills, s)

            objectButton(label: loansAccessibility, action: openLoans) {
                BookObject(
                    family: family, s: s, title: "Loans",
                    value: loansValue, symbol: "building.columns",
                    fill: palette.loans, onFill: family == .poster ? palette.textOnSoft : palette.textOnStrong,
                    progress: store.activeLoans.isEmpty ? nil : loansFraction
                )
            }
            .place(HomeCanvas.loans, s)

            objectButton(label: savingsAccessibility, action: openSavings) {
                SavingsObject(
                    family: family, s: s,
                    fraction: savingsFraction,
                    percentText: store.activeSavingsGoals.isEmpty ? "+" : percent(savingsFraction),
                    valueText: savingsValue
                )
            }
            .place(HomeCanvas.savings, s)

            objectButton(label: NSLocalizedString("Overview", comment: "Home object"), action: onOpenOverview) {
                OverviewObject(family: family, s: s, slices: pieSlices)
            }
            .place(HomeCanvas.overview, s)

            objectButton(label: remindersAccessibility, action: onOpenReminders) {
                RemindersObject(family: family, s: s, badge: upcomingReminderCount > 0 ? upcomingReminderCount : nil)
            }
            .place(HomeCanvas.reminders, s)

            objectButton(
                label: NSLocalizedString("Change period", comment: "Home object"),
                action: { viewModel.isShowingPeriodPicker = true }
            ) {
                CalendarObject(family: family, s: s, month: monthText, day: dayText)
            }
            .place(HomeCanvas.period, s)

            // The book in her hands is the latest entries.
            Button { onOpenActivities(.all) } label: {
                Color.clear.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("All activity"))
            .place(HomeCanvas.herBook, s)
        }
        .frame(width: width, height: HomeCanvas.height * s)
    }

    private func objectButton<Label: View>(
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Label
    ) -> some View {
        Button(action: action) { content() }
            .buttonStyle(ObjectPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Below the shelves

    /// Quick add and the latest entries, so nothing the classic page offers is
    /// missing here.
    private var belowTheShelves: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Quick add")
            QuickAddBarView(categories: viewModel.quickAddCategories) { category in
                viewModel.beginQuickAdd(category)
            }

            HStack {
                sectionTitle("Recent")
                Spacer()
                Button {
                    onOpenActivities(.all)
                } label: {
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            recentCard
        }
        .padding(.horizontal, AppTheme.pageHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.floor)
    }

    @ViewBuilder
    private var recentCard: some View {
        let recent = Array(store.occurrences(in: period).prefix(recentLimit))

        if recent.isEmpty {
            Text("Nothing recorded in this period yet.")
                .font(.subheadline)
                .foregroundStyle(palette.ink.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 60)
                .themedCard(palette, family)
        } else {
            VStack(spacing: 0) {
                ForEach(recent) { item in
                    Button {
                        viewModel.editingOccurrence = item
                    } label: {
                        TransactionRowView(
                            item: item,
                            category: store.category(for: item.categoryID),
                            currency: currency
                        )
                    }
                    .buttonStyle(.plain)

                    if item.id != recent.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .themedCard(palette, family)
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(family == .cozy
                ? .custom("ChalkboardSE-Bold", size: 20, relativeTo: .headline)
                : .custom("Didot", size: 24, relativeTo: .headline))
            .foregroundStyle(palette.ink)
    }

    // MARK: - Figures

    private var balanceText: String {
        CurrencyFormatting.format(amount: summary.netBalance, currency: currency)
    }

    private var balanceCaption: String {
        summary.netBalance < 0
            ? NSLocalizedString("over budget", comment: "Home balance")
            : NSLocalizedString("left to spend", comment: "Home balance")
    }

    private var greeting: String {
        if style.isChristmas {
            return NSLocalizedString("merry & bright ✦", comment: "Home greeting")
        }
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return NSLocalizedString("good morning ✿", comment: "Home greeting")
        case 12..<18: return NSLocalizedString("good afternoon ✿", comment: "Home greeting")
        default: return NSLocalizedString("good evening ✿", comment: "Home greeting")
        }
    }

    private var billsCount: Int {
        store.occurrences(in: period).filter(\.isFeatured).count
    }

    private var billsValue: String {
        billsCount == 0
            ? NSLocalizedString("none yet", comment: "Home bills")
            : String(format: NSLocalizedString("%d this month", comment: "Home bills"), billsCount)
    }

    private var loansFraction: Double {
        let loans = store.activeLoans
        let total = loans.reduce(Decimal.zero) { $0 + $1.loan.initialAmount }
        let paid = loans.reduce(Decimal.zero) { $0 + $1.paidAmount }
        guard total > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: paid / total).doubleValue, 0), 1)
    }

    private var loansValue: String {
        store.activeLoans.isEmpty
            ? NSLocalizedString("add one", comment: "Home loans")
            : String(format: NSLocalizedString("%@ paid", comment: "Home loans"), percent(loansFraction))
    }

    private var savingsFraction: Double {
        let goals = store.activeSavingsGoals
        let target = goals.reduce(Decimal.zero) { $0 + $1.goal.targetAmount }
        let saved = goals.reduce(Decimal.zero) { $0 + $1.savedAmount }
        guard target > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: saved / target).doubleValue, 0), 1)
    }

    private var savingsValue: String {
        let goals = store.activeSavingsGoals
        guard !goals.isEmpty else {
            return NSLocalizedString("set a goal", comment: "Home savings")
        }
        return whole(goals.reduce(Decimal.zero) { $0 + $1.savedAmount })
    }

    private var upcomingReminderCount: Int {
        let horizon = Date().addingTimeInterval(7 * 24 * 3600)
        return store.state.paymentReminders.filter {
            $0.isEnabled && !$0.hasLapsed() && $0.fireDate <= horizon
        }.count
    }

    private var pieSlices: [PieSlice] {
        let spending = store.categorySpending(in: period)
        var slices = spending.prefix(4).map {
            PieSlice(color: CategoryVisuals.tint(for: $0.category), share: $0.share)
        }
        let shown = slices.reduce(0) { $0 + $1.share }
        if shown < 0.999, !slices.isEmpty {
            slices.append(PieSlice(color: palette.ink.opacity(0.18), share: 1 - shown))
        }
        return slices
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("LLL")
        return formatter.string(from: store.periodAnchorDate).uppercased()
    }

    private var dayText: String {
        let date = store.isViewingCurrentPeriod ? Date() : period.start
        return String(Calendar.current.component(.day, from: date))
    }

    private func whole(_ amount: Decimal) -> String {
        CurrencyFormatting.formatWhole(amount: amount, currency: currency)
    }

    private func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    private func openLoans() {
        store.activeLoans.isEmpty ? viewModel.newLoan() : onOpenLoans()
    }

    private func openSavings() {
        store.activeSavingsGoals.isEmpty ? viewModel.newGoal() : onOpenSavings()
    }

    // MARK: - Accessibility

    private var balanceAccessibility: String {
        "\(balanceText), \(balanceCaption)"
    }

    private func bookAccessibility(_ title: String, _ amount: Decimal) -> String {
        "\(NSLocalizedString(title, comment: "Home object")), \(CurrencyFormatting.format(amount: amount, currency: currency))"
    }

    private var billsAccessibility: String {
        "\(NSLocalizedString("Bills", comment: "Home object")), \(billsValue)"
    }

    private var loansAccessibility: String {
        "\(NSLocalizedString("Loans", comment: "Home object")), \(loansValue)"
    }

    private var savingsAccessibility: String {
        store.activeSavingsGoals.isEmpty
            ? NSLocalizedString("Savings, set a goal", comment: "Home object")
            : "\(NSLocalizedString("Savings", comment: "Home object")), \(percent(savingsFraction)), \(savingsValue)"
    }

    private var remindersAccessibility: String {
        upcomingReminderCount == 0
            ? NSLocalizedString("Reminders", comment: "Home object")
            : String(format: NSLocalizedString("Reminders, %d this week", comment: "Home object"), upcomingReminderCount)
    }
}

// MARK: - Canvas

/// Where each object sits on the 1080 x 2340 design (status bar strip above
/// y = 160 is cropped off). Matches the #hit-* rects in Design/*.svg.
enum HomeCanvas {
    static let width: CGFloat = 1080
    static let height: CGFloat = 1920
    static let top: CGFloat = 160

    static let balance = CGRect(x: 90, y: 200, width: 900, height: 220)
    static let expenses = CGRect(x: 95, y: 500, width: 200, height: 360)
    static let income = CGRect(x: 325, y: 530, width: 200, height: 330)
    static let bills = CGRect(x: 555, y: 510, width: 200, height: 350)
    static let loans = CGRect(x: 785, y: 540, width: 200, height: 320)
    static let savings = CGRect(x: 110, y: 990, width: 260, height: 310)
    static let overview = CGRect(x: 410, y: 990, width: 260, height: 310)
    static let reminders = CGRect(x: 710, y: 990, width: 260, height: 310)
    static let period = CGRect(x: 60, y: 1410, width: 200, height: 210)
    static let herBook = CGRect(x: 380, y: 1630, width: 240, height: 160)
}

private extension View {
    func place(_ rect: CGRect, _ s: CGFloat) -> some View {
        frame(width: rect.width * s, height: rect.height * s)
            .position(x: rect.midX * s, y: (rect.midY - HomeCanvas.top) * s)
    }

    func themedCard(_ palette: HomePalette, _ family: HomeStyle.Family) -> some View {
        padding(14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: family == .cozy ? 22 : 4))
            .overlay(
                RoundedRectangle(cornerRadius: family == .cozy ? 22 : 4)
                    .strokeBorder(palette.ink.opacity(family == .cozy ? 0.9 : 1), lineWidth: family == .cozy ? 1.5 : 1)
            )
    }
}

private struct ObjectPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Palette and type

struct HomePalette {
    let ink: Color
    let wall: Color
    let floor: Color
    let card: Color
    let paper: Color
    let expenses: Color
    let income: Color
    let bills: Color
    let loans: Color
    let savings: Color
    let savingsFill: Color
    let badge: Color
    let textOnStrong: Color
    let textOnSoft: Color
    let blush: Color

    init(_ family: HomeStyle.Family) {
        switch family {
        case .cozy:
            ink = Color(hex: 0x5B3B2A)
            wall = Color(hex: 0xF7E6D0)
            floor = Color(hex: 0xE7C29A)
            card = Color(hex: 0xFFF8EC)
            paper = Color(hex: 0xFFF8EC)
            expenses = Color(hex: 0xD9694A)
            income = Color(hex: 0x8FAE7C)
            bills = Color(hex: 0xE3A948)
            loans = Color(hex: 0x8A6A9E)
            savings = Color(hex: 0x4E9A96)
            savingsFill = Color(hex: 0xF3C96B)
            badge = Color(hex: 0xC2453A)
            textOnStrong = Color(hex: 0xFFF6EA)
            textOnSoft = Color(hex: 0xFFF6EA)
            blush = Color(hex: 0xD9694A)
        case .poster:
            ink = Color(hex: 0x1E2340)
            wall = Color(hex: 0xF2EBE1)
            floor = Color(hex: 0xF2EBE1)
            card = Color(hex: 0xF7F2EA)
            paper = Color(hex: 0xF2EBE1)
            expenses = Color(hex: 0xD2654A)
            income = Color(hex: 0x9DB89A)
            bills = Color(hex: 0xF1D488)
            loans = Color(hex: 0xB9A6CF)
            savings = Color(hex: 0x9DB89A)
            savingsFill = Color(hex: 0xF1D488)
            badge = Color(hex: 0x1E2340)
            textOnStrong = Color(hex: 0xF2EBE1)
            textOnSoft = Color(hex: 0x1E2340)
            blush = Color(hex: 0xEDBFB3)
        }
    }
}

private enum HomeType {
    static func hand(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular", fixedSize: size)
    }

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        let font = Font.custom("Didot", fixedSize: size)
        return italic ? font.italic() : font
    }

    static func caps(_ size: CGFloat) -> Font {
        .custom("AvenirNext-DemiBold", fixedSize: size)
    }
}

// MARK: - Objects

private struct BalanceObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let greeting: String
    let amount: String
    let caption: String

    var body: some View {
        let palette = HomePalette(family)

        switch family {
        case .cozy:
            VStack(spacing: 6 * s) {
                Text(greeting).font(HomeType.hand(30 * s))
                Text(amount)
                    .font(HomeType.hand(78 * s, bold: true))
                    .foregroundStyle(palette.savings)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(caption).font(HomeType.hand(25 * s)).opacity(0.7)
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 30 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 34 * s))
            .overlay(RoundedRectangle(cornerRadius: 34 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
        case .poster:
            VStack(spacing: 8 * s) {
                Text(greeting.uppercased()).font(HomeType.caps(20 * s)).tracking(4 * s).opacity(0.7)
                Text(amount)
                    .font(HomeType.serif(112 * s))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(caption.uppercased()).font(HomeType.caps(22 * s)).tracking(5 * s)
            }
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
    }
}

private struct BookObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let fill: Color
    let onFill: Color
    var badge: Int?
    var progress: Double?

    var body: some View {
        let palette = HomePalette(family)

        ZStack(alignment: .topTrailing) {
            switch family {
            case .cozy:
                RoundedRectangle(cornerRadius: 16 * s)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 16 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
                    .overlay(alignment: .top) { band(palette).padding(.top, 30 * s) }
                    .overlay(alignment: .bottom) { band(palette).padding(.bottom, 30 * s) }
            case .poster:
                Rectangle()
                    .fill(fill)
                    .overlay(alignment: .trailing) {
                        HatchShape(spacing: 13 * s)
                            .stroke(palette.ink.opacity(0.35), lineWidth: 2.4 * s)
                            .frame(width: 67 * s)
                            .clipped()
                    }
                    .overlay(
                        Rectangle()
                            .strokeBorder(palette.ink, lineWidth: 3 * s)
                            .offset(x: 7 * s, y: -6 * s)
                    )
            }

            content(palette)

            if let badge {
                Text("\(badge)")
                    .font(family == .cozy ? HomeType.hand(32 * s, bold: true) : HomeType.serif(34 * s))
                    .foregroundStyle(palette.textOnStrong)
                    .frame(width: 60 * s, height: 60 * s)
                    .background(palette.badge, in: Circle())
                    .overlay(Circle().strokeBorder(palette.ink, lineWidth: family == .cozy ? 4 * s : 0))
                    .offset(x: 12 * s, y: -12 * s)
            }
        }
    }

    private func band(_ palette: HomePalette) -> some View {
        Capsule().fill(palette.textOnStrong.opacity(0.85)).frame(height: 3 * s).padding(.horizontal, 20 * s)
    }

    @ViewBuilder
    private func content(_ palette: HomePalette) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if family == .cozy {
                Image(systemName: symbol)
                    .font(.system(size: 38 * s, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 92 * s, height: 92 * s)
                    .background(palette.textOnStrong, in: Circle())
                    .overlay(Circle().strokeBorder(palette.ink, lineWidth: 4 * s))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 44 * s, weight: .regular))
                    .foregroundStyle(palette.ink)
            }
            Spacer(minLength: 0).frame(maxHeight: 40 * s)

            Group {
                if family == .cozy {
                    Text(title).font(HomeType.hand(34 * s, bold: true))
                } else {
                    Text(title).textCase(.uppercase).font(HomeType.caps(21 * s)).tracking(4 * s)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(value)
                .font(family == .cozy ? HomeType.hand(27 * s) : HomeType.serif(40 * s, italic: progress != nil || badge != nil))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 8 * s)

            if let progress {
                ZStack(alignment: .leading) {
                    Capsule().fill(onFill.opacity(family == .cozy ? 0.45 : 0.25))
                    Capsule().fill(family == .cozy ? onFill : palette.ink)
                        .frame(width: 120 * s * progress)
                }
                .frame(width: 120 * s, height: (family == .cozy ? 16 : 7) * s)
                .padding(.top, 12 * s)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(onFill)
        .padding(.horizontal, 14 * s)
        .padding(.vertical, 40 * s)
        // Fill the book, so the column centres instead of following the
        // top-trailing alignment the badge needs.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SavingsObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let fraction: Double
    let percentText: String
    let valueText: String

    var body: some View {
        let palette = HomePalette(family)

        switch family {
        case .cozy:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10 * s)
                    .fill(Color(hex: 0xB9794F))
                    .overlay(RoundedRectangle(cornerRadius: 10 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
                    .frame(width: 210 * s, height: 38 * s)
                    .zIndex(1)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 26 * s).fill(Color.white.opacity(0.6))
                    CoinsShape(s: s)
                        .fill(palette.savingsFill)
                        .overlay(CoinsShape(s: s).stroke(palette.ink, lineWidth: 3 * s))
                        .frame(height: max(30 * s, 260 * s * fraction))
                        .clipShape(RoundedRectangle(cornerRadius: 26 * s))
                    RoundedRectangle(cornerRadius: 26 * s).strokeBorder(palette.ink, lineWidth: 4 * s)

                    VStack(spacing: 2 * s) {
                        Text("Savings").font(HomeType.hand(28 * s, bold: true))
                        Text("\(percentText) · \(valueText)")
                            .font(HomeType.hand(22 * s))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundStyle(palette.textOnStrong)
                    .padding(.horizontal, 12 * s)
                    .padding(.vertical, 10 * s)
                    .frame(width: 180 * s)
                    .background(palette.savings, in: RoundedRectangle(cornerRadius: 12 * s))
                    .overlay(RoundedRectangle(cornerRadius: 12 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50 * s)
                }
                .frame(width: 224 * s)
                .offset(y: -4 * s)
            }
        case .poster:
            let arch = UnevenRoundedRectangle(topLeadingRadius: 110 * s, topTrailingRadius: 110 * s)
            ZStack(alignment: .bottom) {
                arch.fill(palette.savings)
                Rectangle()
                    .fill(palette.savingsFill)
                    .overlay(HatchShape(spacing: 13 * s).stroke(palette.ink.opacity(0.25), lineWidth: 2.4 * s))
                    .frame(height: max(20 * s, 300 * s * fraction))
                    .clipShape(arch)
                arch.stroke(palette.ink, lineWidth: 3 * s).offset(x: 7 * s, y: -6 * s)

                VStack(spacing: 6 * s) {
                    Text("Savings").textCase(.uppercase).font(HomeType.caps(19 * s)).tracking(4 * s)
                    Text(percentText).font(HomeType.serif(52 * s))
                    Text(valueText).font(HomeType.serif(28 * s, italic: true)).lineLimit(1).minimumScaleFactor(0.5)
                }
                .foregroundStyle(palette.ink)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 90 * s)
            }
            .frame(width: 220 * s)
        }
    }
}

struct PieSlice: Hashable {
    let color: Color
    let share: Double
}

private struct OverviewObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let slices: [PieSlice]

    var body: some View {
        let palette = HomePalette(family)
        let diameter = 200 * s

        VStack(spacing: family == .cozy ? 0 : 26 * s) {
            ZStack {
                Circle().fill(palette.card)
                PieView(slices: slices, empty: palette.ink.opacity(0.12))
                    .padding(family == .cozy ? 8 * s : 0)
                if family == .poster {
                    Circle().fill(palette.paper).frame(width: 60 * s)
                    Circle().stroke(palette.ink, lineWidth: 3 * s).offset(x: 7 * s, y: -6 * s)
                } else {
                    Circle().strokeBorder(palette.ink, lineWidth: 4 * s)
                }
            }
            .frame(width: diameter, height: diameter)

            if family == .cozy {
                EaselLegs().stroke(palette.ink, style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
                    .frame(width: 100 * s, height: 30 * s)
                objectCard("Overview", palette)
            } else {
                Text("Overview").textCase(.uppercase).font(HomeType.caps(19 * s)).tracking(4 * s)
                    .foregroundStyle(palette.ink)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func objectCard(_ title: LocalizedStringKey, _ palette: HomePalette) -> some View {
        Text(title)
            .font(HomeType.hand(29 * s, bold: true))
            .foregroundStyle(palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 190 * s, height: 58 * s)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 12 * s))
            .overlay(RoundedRectangle(cornerRadius: 12 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
    }
}

private struct RemindersObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let badge: Int?

    var body: some View {
        let palette = HomePalette(family)
        let face = family == .cozy ? palette.card : palette.bills

        VStack(spacing: family == .cozy ? 4 * s : 26 * s) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    HStack(spacing: 56 * s) {
                        Circle().fill(family == .cozy ? palette.bills : palette.ink)
                            .overlay(Circle().strokeBorder(palette.ink, lineWidth: family == .cozy ? 4 * s : 0))
                            .frame(width: 58 * s)
                        Circle().fill(family == .cozy ? palette.bills : palette.ink)
                            .overlay(Circle().strokeBorder(palette.ink, lineWidth: family == .cozy ? 4 * s : 0))
                            .frame(width: 58 * s)
                    }
                    .offset(y: -82 * s)

                    Circle().fill(face).frame(width: 196 * s)
                    if family == .cozy {
                        Circle().strokeBorder(palette.ink, lineWidth: 4 * s).frame(width: 196 * s)
                    } else {
                        Circle().stroke(palette.ink, lineWidth: 3 * s).frame(width: 196 * s).offset(x: 7 * s, y: -6 * s)
                    }
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        ClockHands(date: context.date)
                            .stroke(palette.ink, style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
                            .frame(width: 196 * s, height: 196 * s)
                    }
                    Circle().fill(palette.ink).frame(width: 14 * s)
                }
                .frame(width: 240 * s, height: 220 * s)

                if let badge {
                    Text("\(badge)")
                        .font(family == .cozy ? HomeType.hand(30 * s, bold: true) : HomeType.serif(32 * s))
                        .foregroundStyle(palette.textOnStrong)
                        .frame(width: 54 * s, height: 54 * s)
                        .background(family == .cozy ? palette.badge : palette.expenses, in: Circle())
                        .overlay(Circle().strokeBorder(palette.ink, lineWidth: family == .cozy ? 4 * s : 0))
                }
            }

            if family == .cozy {
                Text("Reminders")
                    .font(HomeType.hand(29 * s, bold: true))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 190 * s, height: 58 * s)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 12 * s))
                    .overlay(RoundedRectangle(cornerRadius: 12 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
            } else {
                Text("Reminders").textCase(.uppercase).font(HomeType.caps(19 * s)).tracking(4 * s)
                    .foregroundStyle(palette.ink)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

private struct CalendarObject: View {
    let family: HomeStyle.Family
    let s: CGFloat
    let month: String
    let day: String

    var body: some View {
        let palette = HomePalette(family)

        switch family {
        case .cozy:
            VStack(spacing: 0) {
                Text(month)
                    .font(HomeType.hand(32 * s, bold: true))
                    .foregroundStyle(palette.textOnStrong)
                    .frame(maxWidth: .infinity, minHeight: 52 * s)
                    .background(palette.expenses)
                Text(day)
                    .font(HomeType.hand(76 * s, bold: true))
                    .foregroundStyle(palette.ink)
                    .frame(maxHeight: .infinity)
                Text("change period")
                    .font(HomeType.hand(20 * s))
                    .foregroundStyle(palette.ink.opacity(0.7))
                    .padding(.bottom, 14 * s)
            }
            .background(palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16 * s))
            .overlay(RoundedRectangle(cornerRadius: 16 * s).strokeBorder(palette.ink, lineWidth: 4 * s))
        case .poster:
            VStack(spacing: 0) {
                Text(month)
                    .font(HomeType.caps(24 * s)).tracking(5 * s)
                    .foregroundStyle(palette.paper)
                    .frame(maxWidth: .infinity, minHeight: 54 * s)
                    .background(palette.ink)
                Text(day)
                    .font(HomeType.serif(100 * s))
                    .foregroundStyle(palette.ink)
                    .frame(maxHeight: .infinity)
            }
            .background(palette.blush)
            .overlay(Rectangle().strokeBorder(palette.ink, lineWidth: 3 * s).offset(x: 7 * s, y: -6 * s))
        }
    }
}

// MARK: - Shapes

nonisolated private struct HatchShape: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

/// Stacked coin ellipses filling the rect from the bottom.
nonisolated private struct CoinsShape: Shape {
    let s: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let coinWidth = 60 * s
        let coinHeight = 22 * s
        var row = 0
        var y = rect.maxY - coinHeight
        while y > rect.minY - coinHeight / 2 {
            let shift = row.isMultiple(of: 2) ? 0 : coinWidth / 2
            var x = rect.minX - shift
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x, y: y, width: coinWidth, height: coinHeight))
                x += coinWidth + 6 * s
            }
            y -= coinHeight - 4 * s
            row += 1
        }
        return path
    }
}

nonisolated private struct EaselLegs: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

nonisolated private struct ClockHands: Shape {
    let date: Date

    func path(in rect: CGRect) -> Path {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: date) % 12)
        let minute = Double(calendar.component(.minute, from: date))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        func point(angle: Double, length: CGFloat) -> CGPoint {
            let radians = (angle - 90) * .pi / 180
            return CGPoint(
                x: center.x + cos(radians) * length,
                y: center.y + sin(radians) * length
            )
        }

        var path = Path()
        path.move(to: center)
        path.addLine(to: point(angle: (hour + minute / 60) * 30, length: radius * 0.45))
        path.move(to: center)
        path.addLine(to: point(angle: minute * 6, length: radius * 0.68))
        return path
    }
}

private struct PieView: View {
    let slices: [PieSlice]
    let empty: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(size.width, size.height) / 2

            guard !slices.isEmpty else {
                context.fill(Path(ellipseIn: rect), with: .color(empty))
                return
            }

            var start = -90.0
            for slice in slices {
                let end = start + slice.share * 360
                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                path.closeSubpath()
                context.fill(path, with: .color(slice.color))
                start = end
            }
        }
    }
}

// MARK: - Settings thumbnail

/// One home page choice in Settings: a small picture with its name.
struct HomeStyleThumbnail: View {
    let style: HomeStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image("thumb-\(style.rawValue)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(4)
                        }
                    }

                Text(style.localizedTitle)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 80)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(style.localizedTitle))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
