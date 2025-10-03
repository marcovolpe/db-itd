<# 
  pack-mac-from-windows.ps1
  Crea OfflineFinder-macOS.zip contenente:
    - "Offline Finder.app"
    - "data/db.sqlite"
    - "README-macOS.txt"

  Modalità d’uso:
  1) Locale (hai già la .app):
     .\pack-mac-from-windows.ps1 -AppDir "C:\percorso\Offline Finder.app"

     (oppure se hai uno zip con dentro la .app:)
     .\pack-mac-from-windows.ps1 -AppZip "C:\percorso\OfflineFinder-macOS-app.zip"

  2) CI GitHub (scarica l’artefatto automaticamente):
     Imposta le variabili d’ambiente:
       $env:GITHUB_TOKEN = "<token PAT con permesso 'actions:read'>"
       $env:GITHUB_REPO  = "utente/repo"    # es: "marco/offline-finder"
       $env:ARTIFACT_NAME = "macos-app"     # nome artefatto creato dalla workflow
     Poi:
       .\pack-mac-from-windows.ps1 -FromGitHub

  Requisiti su Windows:
  - db in .\data\db.sqlite
  - Se usi -FromGitHub: curl.exe e tar.exe disponibili (sono nel PATH di Windows 10/11)
#>

[CmdletBinding()]
param(
  [string]$AppDir,         # path a "Offline Finder.app"
  [string]$AppZip,         # zip che contiene la .app
  [switch]$FromGitHub      # scarica artefatto da GitHub Actions
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Info($m){ Write-Host "[i] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[✓] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ROOT

# 0) Verifica DB
$dbSrc = Join-Path $ROOT "data\db.sqlite"
if (!(Test-Path $dbSrc)) { Err "data\db.sqlite non trovato"; exit 1 }

# 1) Sorgente .app
$tempBase = Join-Path $env:TEMP "pack-mac-from-win"
if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
New-Item -ItemType Directory -Path $tempBase | Out-Null

$AppPath = $null

if ($PSBoundParameters.ContainsKey('AppDir')) {
  if (!(Test-Path $AppDir)) { Err "AppDir non esiste: $AppDir"; exit 1 }
  if ((Split-Path -Leaf $AppDir) -notlike "*.app") { 
    Err "AppDir deve puntare alla cartella .app (es: ...\Offline Finder.app)"; exit 1 
  }
  $AppPath = (Resolve-Path $AppDir).Path
  Info "Userò la .app locale: $AppPath"
}
elseif ($PSBoundParameters.ContainsKey('AppZip')) {
  if (!(Test-Path $AppZip)) { Err "AppZip non esiste: $AppZip"; exit 1 }
  Info "Estraggo AppZip: $AppZip"
  $zipExtract = Join-Path $tempBase "appzip"
  New-Item -ItemType Directory -Path $zipExtract | Out-Null
  Expand-Archive -Path $AppZip -DestinationPath $zipExtract -Force
  $apps = Get-ChildItem -Path $zipExtract -Recurse -Directory -Filter "*.app"
  if ($apps.Count -eq 0) { Err "Nessuna .app trovata dentro lo zip"; exit 1 }
  # preferisci quella che contiene "Offline" o "Finder"
  $preferred = $apps | Where-Object { $_.Name -match '(?i)offline|finder' } | Select-Object -First 1
  if (-not $preferred) { $preferred = $apps | Select-Object -First 1 }
  $AppPath = $preferred.FullName
  Ok "Trovata .app nello zip: $AppPath"
}
elseif ($FromGitHub) {
  # scarica l’artefatto macOS dalla GitHub Actions
  $token = $env:GITHUB_TOKEN
  $repo  = $env:GITHUB_REPO
  $artifactName = $env:ARTIFACT_NAME
  if ([string]::IsNullOrWhiteSpace($token) -or [string]::IsNullOrWhiteSpace($repo) -or [string]::IsNullOrWhiteSpace($artifactName)) {
    Err "Per -FromGitHub servono le env: GITHUB_TOKEN, GITHUB_REPO, ARTIFACT_NAME"; exit 1
  }
  Info "Scarico ultimo artefatto '$artifactName' da $repo …"
  $headers = @{ "Authorization" = "Bearer $token"; "Accept"="application/vnd.github+json" }

  # 1) prendi lista artefatti
  $artifactsUrl = "https://api.github.com/repos/$repo/actions/artifacts?per_page=100"
  $resp = Invoke-RestMethod -Headers $headers -Uri $artifactsUrl -Method GET
  $art = $resp.artifacts | Where-Object { $_.name -eq $artifactName -and $_.expired -eq $false } | Sort-Object -Property created_at -Descending | Select-Object -First 1
  if (-not $art) { Err "Artefatto '$artifactName' non trovato o scaduto"; exit 1 }

  # 2) scarica zip binario
  $downloadUrl = "https://api.github.com/repos/$repo/actions/artifacts/$($art.id)/zip"
  $artifactZip = Join-Path $tempBase "artifact.zip"
  Invoke-WebRequest -Headers $headers -Uri $downloadUrl -OutFile $artifactZip
  Info "Estraggo artefatto…"
  $artExtract = Join-Path $tempBase "artifact"
  New-Item -ItemType Directory -Path $artExtract | Out-Null
  Expand-Archive -Path $artifactZip -DestinationPath $artExtract -Force

  # 3) trova .app
  $apps = Get-ChildItem -Path $artExtract -Recurse -Directory -Filter "*.app"
  if ($apps.Count -eq 0) { Err "Nessuna .app trovata nell’artefatto"; exit 1 }
  $preferred = $apps | Where-Object { $_.Name -match '(?i)offline|finder' } | Select-Object -First 1
  if (-not $preferred) { $preferred = $apps | Select-Object -First 1 }
  $AppPath = $preferred.FullName
  Ok "Trovata .app dall’artefatto: $AppPath"
}
else {
  Err "Specifica uno tra: -AppDir, -AppZip, -FromGitHub"; exit 1
}

# 2) Prepara cartella distributiva
$distRoot  = Join-Path $ROOT "dist-offline"
$bundleDir = Join-Path $distRoot "OfflineFinder-macOS"
if (Test-Path $bundleDir) { Remove-Item $bundleDir -Recurse -Force }
New-Item -ItemType Directory -Path $bundleDir | Out-Null

# 3) Copia la .app (cartella)
Info "Copio .app → $bundleDir"
Copy-Item -Path $AppPath -Destination $bundleDir -Recurse

# 4) Copia DB accanto alla .app in data/
$targetData = Join-Path $bundleDir "data"
New-Item -ItemType Directory -Path $targetData | Out-Null
Copy-Item $dbSrc $targetData

# 5) README
$readme = @"
Offline Finder (versione portabile per macOS)

Come usare:
1) Apri la cartella "OfflineFinder-macOS".
2) Tieni "Offline Finder.app" e la cartella "data" insieme (stesso livello).
3) Clic destro su "Offline Finder.app" → Apri (la prima volta, per superare Gatekeeper).
4) Il database è letto da "data/db.sqlite" accanto all'app.
5) Per aggiornare i dati, sostituisci quel file con uno più recente.

Note:
- L'app funziona completamente offline.
- Se vuoi spostarla, sposta sia la .app sia la cartella "data".
"@
Set-Content -Path (Join-Path $bundleDir "README-macOS.txt") -Value $readme -Encoding UTF8

# 6) Crea ZIP finale
$zipPath = Join-Path $distRoot "OfflineFinder-macOS.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Info "Creo ZIP: $zipPath"

# Compress-Archive gestisce anche directory con estensione .app (sono cartelle)
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $zipPath

Ok "Pronto! -> $zipPath"
