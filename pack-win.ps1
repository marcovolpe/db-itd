# pack-win.ps1 — Crea ZIP portabile "OfflineFinder-Windows.zip"
# Robusto: gestisce EXE sia in bundle\app\** sia in target\release\
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Info($m){ Write-Host "[i] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[✓] $m" -ForegroundColor Green }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 0) Verifica DB
$dbSrc = Join-Path $root "data\db.sqlite"
if (!(Test-Path $dbSrc)) { Err "data\db.sqlite non trovato"; exit 1 }

# 1) Build prod (Vite + Tauri)
Info "Build produzione…"
npm run build | Out-Host

# 2) Trova l'eseguibile in posizioni note
$candidates = @()

$pathA = "src-tauri\target\release\bundle\app"
if (Test-Path $pathA) {
  $candidates += Get-ChildItem -Path $pathA -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue
}

$pathB = "src-tauri\target\release\bundle"
if (Test-Path $pathB) {
  $candidates += Get-ChildItem -Path $pathB -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue
}

$pathC = "src-tauri\target\release"
if (Test-Path $pathC) {
  $candidates += Get-ChildItem -Path $pathC -Filter "*.exe" -ErrorAction SilentlyContinue
}

if ($candidates.Count -eq 0) {
  Err "Nessun eseguibile trovato in src-tauri\target\release*"
  exit 1
}

# preferisci exe con nome “offline” o “finder”
$exe = $candidates | Where-Object { $_.Name -match '(?i)offline|finder' } | Select-Object -First 1
if (-not $exe) { $exe = $candidates | Select-Object -First 1 }

Ok ("Eseguibile: {0}" -f $exe.FullName)

# 3) Prepara cartella distributiva
$distRoot = Join-Path $root "dist-offline"
if (!(Test-Path $distRoot)) { New-Item -ItemType Directory -Path $distRoot | Out-Null }

$bundleDir = Join-Path $distRoot "OfflineFinder-Windows"
if (Test-Path $bundleDir) { Remove-Item $bundleDir -Recurse -Force }
New-Item -ItemType Directory -Path $bundleDir | Out-Null

# 4) Copia TUTTI i file accanto all'EXE (exe, dll, .pak, ecc.)
Info "Copio binari runtime da: $($exe.DirectoryName)"
Copy-Item -Path (Join-Path $exe.DirectoryName "*") -Destination $bundleDir -Recurse

# 5) Copia DB in data/
$targetData = Join-Path $bundleDir "data"
New-Item -ItemType Directory -Path $targetData | Out-Null
Copy-Item $dbSrc $targetData

# 6) README
$readme = @"
Offline Finder (versione portabile)

Come usare:
1) Avvia l'eseguibile (Offline Finder.exe).
2) Il database è letto da "data\db.sqlite" accanto all'eseguibile.
3) Per aggiornare i dati, sostituisci quel file con uno più recente.

Note:
- L'app funziona completamente offline.
- Se SmartScreen avverte, conferma l'esecuzione (software interno).
"@
Set-Content -Path (Join-Path $bundleDir "README.txt") -Value $readme -Encoding UTF8

# 7) ZIP finale
$zipPath = Join-Path $distRoot "OfflineFinder-Windows.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Info "Creo ZIP: $zipPath"
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $zipPath

Ok "Pronto! -> $zipPath"
