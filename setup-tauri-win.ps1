# setup-tauri-win.ps1
# Esegui come AMMINISTRATORE in PowerShell.
# Installa: WebView2, Rust (MSVC), aggiunge PATH, e (opzionale) VS Build Tools per Tauri.

$ErrorActionPreference = "Stop"

function Info($m){ Write-Host "[i] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[✓] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

# 0) Controllo privilegi
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if(-not $admin){
  Warn "Non stai eseguendo come Amministratore. Alcune installazioni potrebbero fallire."
}

# 1) WebView2 Runtime (obbligatorio per Tauri)
try {
  Info "Installo Microsoft Edge WebView2 Runtime (winget)…"
  winget install --id Microsoft.EdgeWebView2Runtime --source winget --accept-source-agreements --accept-package-agreements -e
  Ok "WebView2 installato (o già presente)."
} catch {
  Warn "Winget non disponibile o installazione WebView2 non riuscita. Proverai l'app: se mancherà, scaricalo dal sito Microsoft."
}

# 2) Rust (MSVC) con winget; fallback rustup-init
$rustOk = $false
try {
  Info "Installo Rust (MSVC) via winget…"
  winget install --id Rustlang.Rust.MSVC --source winget --accept-source-agreements --accept-package-agreements -e
  $rustOk = $true
} catch {
  Warn "Winget non disponibile o installazione Rust via winget fallita. Passo al fallback rustup-init."
}

if(-not $rustOk){
  $tmp = Join-Path $env:TEMP "rustup-init.exe"
  Info "Scarico rustup-init.exe…"
  Invoke-WebRequest https://win.rustup.rs/x86_64 -OutFile $tmp
  Info "Eseguo rustup-init (default MSVC)…"
  & $tmp -y | Out-Null
  Remove-Item $tmp -ErrorAction SilentlyContinue
  $rustOk = $true
}

# 3) Aggiungi PATH permanente per Cargo (se mancante)
$cargoBin = Join-Path $HOME ".cargo\bin"
if(-not (Test-Path $cargoBin)){ 
  Warn "La cartella $cargoBin non esiste ancora (installazione Rust non ha creato i file?). Continuo comunque." 
}
$envPathUser = [Environment]::GetEnvironmentVariable("Path","User")
if($envPathUser -notlike "*$cargoBin*"){
  Info "Aggiungo $cargoBin al PATH utente…"
  [Environment]::SetEnvironmentVariable("Path", $envPathUser + ";" + $cargoBin, "User")
  Ok "PATH aggiornato. Apri una NUOVA finestra di PowerShell dopo lo script."
} else {
  Ok "PATH già contiene $cargoBin."
}

# 4) Verifica rustup/cargo/rustc nella sessione corrente (provo anche ad aggiornare PATH live)
if(-not (Get-Command rustup -ErrorAction SilentlyContinue)){
  $env:Path += ";$cargoBin"
}
try {
  Info "Verifico toolchain Rust…"
  rustup default stable | Out-Null
  rustup update | Out-Null
  $v1 = cargo -V
  $v2 = rustc -V
  $v3 = rustup -V
  Ok "Rust ok: $v1 | $v2 | $v3"
} catch {
  Err "Rust non disponibile nella sessione. Chiudi e riapri PowerShell, poi verifica con: cargo -V"
}

# 5) (Opzionale ma consigliato) Installa VS Build Tools (C++ + Windows 10/11 SDK) in modalità silenziosa
#    Serve per compilare Tauri su Windows con toolchain MSVC.
#    Se sono già installati, puoi saltare. Imposta $InstallBuildTools=$false per saltare.
$InstallBuildTools = $true
if($InstallBuildTools){
  try {
    Info "Installo Visual Studio Build Tools (C++ + SDK) in modalità silenziosa (può richiedere diversi minuti)…"
    $bt = Join-Path $env:TEMP "vs_BuildTools.exe"
    Invoke-WebRequest "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $bt
    # Componenti: workload VCTools, MSVC, Windows SDK 10, CMake, Ninja
    $args = @(
      "--quiet", "--wait", "--norestart", "--nocache",
      "--add", "Microsoft.VisualStudio.Workload.VCTools",
      "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
      "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041",
      "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project",
      "--add", "Microsoft.VisualStudio.Component.VC.Llvm.Clang",
      "--add", "Microsoft.VisualStudio.Component.VC.CoreBuildTools",
      "--includeRecommended"
    )
    & $bt $args
    Ok "Build Tools installati (o già presenti)."
    Remove-Item $bt -ErrorAction SilentlyContinue
  } catch {
    Warn "Installazione Build Tools non riuscita da script. Puoi installarli manualmente con Visual Studio Installer → 'Desktop development with C++'."
  }
}

# 6) Verifica minima ambiente Tauri
try {
  Info "Verifico ambiente Tauri (npx tauri info)…"
  npx tauri info
  Ok "Ambiente Tauri pronto."
} catch {
  Warn "Impossibile eseguire 'npx tauri info' ora. Dopo aver RIAPERTO PowerShell, prova: npx tauri info"
}

Ok "Setup completato. Ora APRI UNA NUOVA PowerShell e lancia nella cartella del progetto: 'npm install' e poi 'npm run dev'."
