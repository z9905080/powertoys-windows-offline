# powertoys-windows-offline

Microsoft PowerToys **Windows x64 完全離線安裝包**。

本 repo 直接收錄官方 GitHub Releases 的 **x64 安裝程式**（未修改任何位元組；因單檔超過 GitHub 100 MiB 上限，以 90 MiB 分割存放）。clone 或整個資料夾帶到目標電腦後即可安裝，安裝過程**不需要網路**、不需要 Git LFS。預設為「目前使用者」安裝，不必系統管理員權限。

| 項目 | 內容 |
|---|---|
| 版本 | **0.102.3101.0**（官方 tag `v0.102.3101`） |
| 官方來源 | https://github.com/microsoft/PowerToys/releases/tag/v0.102.3101 |
| 發行時間 | 2026-11-06 17:54（台北時間，UTC+8） |
| 授權 | MIT（Microsoft Corporation，見 `LICENSE`） |

官方發行說明中的 Installer Hashes（本包已逐一核對，完全相符）：

| 種類 | 檔名 | 大小 | 官方 SHA256 |
|---|---|---|---|
| 目前使用者 - x64 | `PowerToysUserSetup-0.102.3101.0-x64.exe` | 323,951,160 位元組（約 309 MB） | `4b4c49a31e8b7e6a36647ccd3033acb0ad56c306595a9409e59865c3c27d1cf2` |
| 整台電腦 - x64 | `PowerToysSetup-0.102.3101.0-x64.exe` | 323,977,120 位元組（約 309 MB） | `f1d24a49346167322eb64a2458bd82810519920d1da4c0aeb1788e54c345d142` |

以上雜湊亦寫在 `windows-x64/official-installers.sha256`。**未收錄 ARM64 安裝程式。**

## 支援環境

與[官方安裝說明](https://learn.microsoft.com/en-us/windows/powertoys/install)相同：

- **Windows 10 版本 2004（20H1 / build 19041）以上 x64**、Windows 11 x64。
- Windows PowerShell 5.1（Windows 內建）或 PowerShell 7 皆可。
- 官方安裝程式會透過 bootstrapper 安裝 **Microsoft Edge WebView2 Runtime**（若系統尚未安裝）。完全離線的電腦請先自行備妥 WebView2，否則安裝可能失敗。
- **不支援**：32 位元 Windows、ARM64 Windows（本包未收錄官方 ARM64 安裝檔）、Windows 10 2004 之前的版本。

## 目錄結構

```
README.md
LICENSE                         # 官方 MIT 授權全文
install.ps1                     # 離線安裝（PowerShell 5.1+）
uninstall.ps1                   # 離線移除（呼叫官方安裝程式 /uninstall）
SHA256SUMS                      # windows-x64/ 下每個已納入檔案的 SHA256
tools/offline-common.ps1        # install / uninstall 共用函式
tests/                          # 可在 Linux 執行的檢查（見「測試」）
windows-x64/
  official-installers.sha256    # 官方完整安裝檔 SHA256
  official-release.txt          # 官方版本與來源
  PowerToysUserSetup-*.exe.part01 … part04
  PowerToysSetup-*.exe.part01 … part04
```

每個分割檔最大 90 MiB（94,371,840 位元組），低於 GitHub 單檔 100 MiB 上限，因此**不使用 Git LFS**。`install.ps1` 會先合併分割檔，再核對完整安裝檔的官方 SHA256，通過後才執行安裝。

## 取得安裝包（在有網路的電腦上）

```powershell
git clone https://github.com/z9905080/powertoys-windows-offline.git
```

接著把**整個資料夾**用隨身碟、內網分享等方式帶到目標電腦。不要只複製 `install.ps1`，它需要旁邊的 `windows-x64\` 與 `SHA256SUMS`。

## 安裝

在目標電腦開啟 PowerShell（**一般使用者即可，不必「以系統管理員身分執行」**），切到安裝包資料夾：

```powershell
cd C:\path\to\powertoys-windows-offline

# 先預覽會做哪些變更，並合併、核對雜湊（不會實際安裝）
powershell -NoProfile -File .\install.ps1 -WhatIf

# 正式安裝（目前使用者，靜默安裝）
powershell -NoProfile -File .\install.ps1
```

安裝程式會：

1. 用 `SHA256SUMS` 驗證 `windows-x64\` 內所有分割檔與說明檔，任何檔案缺漏或損毀就中止。
2. 將對應的分割檔合併成官方安裝程式。
3. 核對合併結果的 SHA256，必須與官方發行說明完全一致。
4. 執行官方安裝程式，參數為 `/install /quiet /norestart`（另寫入暫存安裝記錄）。這些是官方文件所列的 Microsoft Standard Installer 選項（`/quiet` 為靜默安裝；`/norestart` 避免安裝程式自行重開機）。

可選參數：

| 參數 | 作用 |
|---|---|
| `-WhatIf` | 仍會合併並核對雜湊，但不執行官方安裝程式 |
| `-MachineWide` | 改用整台電腦安裝檔（需「以系統管理員身分」開啟 PowerShell） |
| `-Interactive` | 改開官方安裝介面，不使用靜默參數 |

安裝完成後，可從開始功能表開啟 **PowerToys**。官方安裝位置：目前使用者為 `%LOCALAPPDATA%\Programs`；整台電腦為 `%ProgramFiles%`。

### 重新安裝 / 升級

換成新版安裝包後再執行一次 `install.ps1` 即可。離線環境不會自動更新到更新的官方版本。

## 移除

可在 Windows「設定 > 應用程式 > 已安裝的應用程式」中解除安裝 PowerToys，或使用本包：

```powershell
cd C:\path\to\powertoys-windows-offline
powershell -NoProfile -File .\uninstall.ps1 -WhatIf   # 預覽
powershell -NoProfile -File .\uninstall.ps1
```

`uninstall.ps1` 同樣會合併、核對官方雜湊，再以 `/uninstall /quiet /norestart` 呼叫官方安裝程式。若當初使用 `-MachineWide` 安裝，移除時也要加上 `-MachineWide`（並以系統管理員身分執行）。本安裝包資料夾本身不會被刪除。

## 驗證雜湊

**驗證分割檔**（`install.ps1` 每次都會自動驗證；也可手動）：

```powershell
# PowerShell：比對單一分割檔
(Get-FileHash .\windows-x64\PowerToysUserSetup-0.102.3101.0-x64.exe.part01 -Algorithm SHA256).Hash.ToLower()
Select-String "UserSetup.*part01" .\SHA256SUMS
```

```bash
# Git Bash / Linux / macOS：一次驗證全部已納入檔案
sha256sum -c SHA256SUMS
```

**驗證合併後的官方安裝檔**（應與上方表格及 `windows-x64/official-installers.sha256` 完全一致）：

```bash
cat windows-x64/PowerToysUserSetup-0.102.3101.0-x64.exe.part* > /tmp/PowerToysUserSetup-0.102.3101.0-x64.exe
cat windows-x64/PowerToysSetup-0.102.3101.0-x64.exe.part* > /tmp/PowerToysSetup-0.102.3101.0-x64.exe
(cd /tmp && sha256sum -c /path/to/powertoys-windows-offline/windows-x64/official-installers.sha256)
```

## PowerShell 執行原則（ExecutionPolicy）注意事項

Windows 用戶端預設的執行原則可能不允許執行本機 `.ps1` 腳本；從網路下載的 ZIP 解壓出的腳本，也可能被 Windows 視為「來自網際網路」。

- 先用 `Get-ExecutionPolicy -List` 查看目前設定。
- **公司或學校管理的電腦**：若 `MachinePolicy` / `UserPolicy` 有設定值，代表由群組原則（GPO）控管。請**向 IT 部門申請核准**執行本安裝包（可提供本 README 與 `SHA256SUMS` 供審查），**不要嘗試繞過**。
- **個人電腦**：Microsoft 文件建議用戶端使用 `RemoteSigned`，可只對目前使用者設定：
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
  在此原則下，git clone 下來的腳本可直接執行；若是由瀏覽器下載的 ZIP，請先核對雜湊，確認來源可信後，再依你的使用政策決定是否於檔案「內容」中解除封鎖。
- 本專案**不建議**使用 `-ExecutionPolicy Bypass`、停用防毒或其他安全機制。本 repo 只是把官方檔案整理成可離線安裝的形式，**不是用來規避企業管控的工具**。

另外，Windows SmartScreen 或防毒軟體可能對官方安裝程式顯示提示，這是正常的安全機制；請先核對雜湊，再依組織政策處理。本安裝程式不會移除檔案的下載標記，也不會變更任何安全設定。

因此本包**不提供**以 Bypass 執行原則的 `install.cmd` 包裝。

## 大小

| 項目 | 大小 |
|---|---|
| 官方目前使用者安裝檔（x64） | 323,951,160 位元組（約 309 MB） |
| 官方整台電腦安裝檔（x64） | 323,977,120 位元組（約 309 MB） |
| 分割檔（各安裝檔 4 段，前 3 段各 90 MiB） | 與官方安裝檔合計相同，約 618 MB |
| clone 後工作目錄 | 約 618 MB（不含 git 物件） |

## 限制

- 只有 Windows x64。ARM64 安裝檔未包含在本包中；若需要請改用官方 ARM64 發行檔。
- 安裝包內的版本固定為 **0.102.3101.0**；離線環境不會自動更新，要升級請取得新版安裝包。
- 已安裝的 PowerToys 若開啟自動更新，仍需要能連到官方更新來源；內網離線環境請關閉自動更新，改用新的離線包升級。
- 官方安裝程式可能需要 Microsoft Edge WebView2 Runtime；完全沒有 WebView2、又無法上網時，請另行離線安裝 WebView2。
- 本 repo 的腳本**尚未在實體 Windows 上做端對端安裝測試**（見下方「測試」）。合併與雜湊核對已在 Linux 上驗證。

## 測試

在 Linux 上可執行（需要 `sha256sum`、`python3`，有 `pwsh` 時另做 PowerShell 語法檢查）：

```bash
tests/run-linux-tests.sh
```

內容包含：`SHA256SUMS` 驗證、分割檔大小上限、合併後與官方 SHA256 相符、PowerShell 語法解析與 ASCII 檢查（Windows PowerShell 5.1 編碼相容）。

**尚未測試**：在真實 Windows 上執行 `install.ps1` / `uninstall.ps1`（官方安裝程式、權限、WebView2、開始功能表捷徑）。歡迎在 Windows 上試用並回報。

## 授權

PowerToys 以 MIT 授權（Copyright (c) Microsoft Corporation），全文見 `LICENSE`。本 repo 僅重新打包**未修改**的官方 x64 安裝程式，並附上離線安裝腳本。
