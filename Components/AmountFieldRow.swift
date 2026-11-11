import SwiftUI

/// "Label ........ 0" money row for forms.
///
/// The whole row is the tap target. A bare TextField after a Spacer only
/// answers taps on its own few points of width, which is why these fields
/// were hard to hit.
struct AmountFieldRow: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var placeholder: String = "0"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(
                placeholder,
                text: Binding(
                    get: { text },
                    set: { text = DecimalAmountValidator.sanitize($0) }
                )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .accessibilityLabel(Text(title))
        }
        .frame(minHeight: AppTheme.minimumTapTarget)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}
