"""Run the actual voice parser with app model definitions on macOS, without a simulator."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "Models/TransactionModels.swift").read_text().split("/// A concrete ledger entry.")[0]
source += (root / "Models/SettingsModels.swift").read_text().split("struct AppSettings:")[0]
# Formatting is unrelated to these tests; avoid bringing SwiftUI into this macOS harness.
source += "\nenum CurrencyFormatting { static func symbol(for currency: Currency) -> String { currency.rawValue }; static func format(amount: Decimal, currency: Currency) -> String { String(describing: amount) } }\n"
source += (root / "Utilities/AppLocalization.swift").read_text()
source += (root / "Utilities/DecimalAmountValidator.swift").read_text()
source += (root / "Services/VoiceEntryParser.swift").read_text()
source += (root / "Services/SpeechLanguages.swift").read_text()
source += (root / "Tests/VoiceEntryParserChecks.swift").read_text()
with tempfile.TemporaryDirectory(prefix="muna-voice-tests-") as directory:
    main = Path(directory) / "main.swift"
    main.write_text(source)
    subprocess.run(["swift", "-module-cache-path", str(Path(directory) / "cache"), str(main)], check=True)
