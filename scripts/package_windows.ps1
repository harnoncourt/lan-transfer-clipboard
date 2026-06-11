param(
  [string]$Version = "0.1.1"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

flutter pub get
flutter build windows --release

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$DistDir = Join-Path $Root "dist"
$ZipPath = Join-Path $DistDir "LAN-Transfer-$Version-windows-x64.zip"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
if (Test-Path $ZipPath) {
  Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath
Write-Host "Created $ZipPath"
