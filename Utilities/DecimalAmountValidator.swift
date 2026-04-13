import Foundation

enum DecimalAmountValidator {
    static func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: ",", with: ".")
    }

    static func isValidAmountInput(_ value: String) -> Bool {
        let input = sanitize(value)
        if input.isEmpty { return true }
        let pattern = "^\\d*(\\.\\d{0,2})?$"
        return input.range(of: pattern, options: .regularExpression) != nil
    }

    static func parsedAmount(from value: String) -> Double? {
        let trimmed = sanitize(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isValidAmountInput(trimmed), let amount = Double(trimmed), amount > 0 else {
            return nil
        }
        return amount
    }
}
