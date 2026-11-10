#!/usr/bin/env bash
# Checks this bundle without Windows. Real install/uninstall needs Windows and is not covered here.
#   tests/run-linux-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PWSH="${PWSH:-$(command -v pwsh || true)}"

echo "== SHA256SUMS (payload)"
sha256sum -c --quiet SHA256SUMS && echo "ok: $(grep -c . SHA256SUMS) files"

echo "== official hashes recorded in official-installers.sha256"
python3 -I - <<'PY'
from pathlib import Path
expected = {
    "PowerToysUserSetup-0.102.3101.0-x64.exe": "4b4c49a31e8b7e6a36647ccd3033acb0ad56c306595a9409e59865c3c27d1cf2",
    "PowerToysSetup-0.102.3101.0-x64.exe": "f1d24a49346167322eb64a2458bd82810519920d1da4c0aeb1788e54c345d142",
}
text = Path("windows-x64/official-installers.sha256").read_text(encoding="ascii")
got = {}
for line in text.splitlines():
    h, name = line.split()
    got[name] = h.lower()
assert got == expected, (got, expected)
print("ok: official SHA256 table matches the published release notes")
PY

echo "== no file over GitHub's 100 MiB limit"
python3 -I - <<'PY'
import os
limit = 100 * 1024 * 1024
biggest = 0
biggest_path = None
over = []
for dirpath, _, files in os.walk("windows-x64"):
    for name in files:
        path = os.path.join(dirpath, name)
        size = os.path.getsize(path)
        if size > biggest:
            biggest, biggest_path = size, path
        if size >= limit:
            over.append((size, path))
if over:
    raise SystemExit("too big: " + repr(over))
print(f"ok: largest {biggest} {biggest_path}")
PY

echo "== no leftover reassembled .exe in the tree"
leftover=$(find . -name '*.exe' -not -path './.git/*' || true)
if [ -n "$leftover" ]; then
  echo "unexpected exe files:"
  echo "$leftover"
  exit 1
fi
echo "ok: no .exe committed"

echo "== reassemble both official installers and verify SHA256"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for name in PowerToysUserSetup-0.102.3101.0-x64.exe PowerToysSetup-0.102.3101.0-x64.exe; do
  # Concatenate in part order (part01, part02, ...).
  cat "windows-x64/${name}.part"* > "$work/$name"
done
(cd "$work" && sha256sum -c "$OLDPWD/windows-x64/official-installers.sha256")
# Also compare to the original official downloads when present.
if [ -d /workspace/powertoys-dl ]; then
  echo "== byte-identical to the official downloads in /workspace/powertoys-dl"
  cmp -s /workspace/powertoys-dl/PowerToysUserSetup-0.102.3101.0-x64.exe "$work/PowerToysUserSetup-0.102.3101.0-x64.exe"
  cmp -s /workspace/powertoys-dl/PowerToysSetup-0.102.3101.0-x64.exe "$work/PowerToysSetup-0.102.3101.0-x64.exe"
  echo "ok: identical to official downloads"
fi

echo "== PowerShell scripts are ASCII (Windows PowerShell 5.1 encoding)"
python3 -I - <<'PY'
from pathlib import Path
files = list(Path(".").glob("*.ps1")) + list(Path("tools").glob("*.ps1"))
for path in files:
    data = path.read_bytes()
    if b"\0" in data:
        raise SystemExit(f"nul byte in {path}")
    try:
        text = data.decode("ascii")
    except UnicodeDecodeError as exc:
        raise SystemExit(f"non-ASCII in {path}: {exc}") from exc
    print(f"ok: {path} ascii ({len(text)} chars)")
PY

if [ -n "$PWSH" ]; then
  echo "== PowerShell parse ($("$PWSH" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'))"
  "$PWSH" -NoProfile -Command '
    $ErrorActionPreference = "Stop"
    $files = @("install.ps1", "uninstall.ps1", "tools/offline-common.ps1")
    foreach ($f in $files) {
      $errs = $null
      $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) $f), [ref]$null, [ref]$errs)
      if ($errs -and $errs.Count) {
        $errs | ForEach-Object { Write-Host $_.ToString() }
        exit 1
      }
      Write-Host "ok: parse $f"
    }
  '
else
  echo "== PowerShell parse skipped (pwsh not installed)"
fi

echo "All Linux checks passed."
