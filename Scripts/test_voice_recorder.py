"""Check production recorder lifecycle against test-only Speech/audio stand-ins."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
recorder = (root / "Services/VoiceEntryRecorder.swift").read_text()
recorder = recorder.replace("import AVFoundation", "").replace("@preconcurrency import Speech", "")
source = (root / "Tests/VoiceEntryRecorderFakes.swift").read_text()
source += (root / "Utilities/AppLocalization.swift").read_text()
source += recorder
source += (root / "Tests/VoiceEntryRecorderChecks.swift").read_text()
with tempfile.TemporaryDirectory(prefix="muna-recorder-tests-") as directory:
    main = Path(directory) / "main.swift"
    executable = Path(directory) / "checks"
    main.write_text(source)
    subprocess.run(["swiftc", "-swift-version", "6", "-parse-as-library", "-module-cache-path", str(Path(directory) / "cache"), str(main), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
