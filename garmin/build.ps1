# Builds BreezUp for the Instinct 3 Solar.  Usage:  .\build.ps1  [-Run]
#   -Run  also starts the Connect IQ simulator and loads the app into it.
param([switch]$Run)

$ErrorActionPreference = 'Stop'
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
$jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Sort-Object Name -Descending | Select-Object -First 1
$env:JAVA_HOME = $jdk.FullName
$env:PATH = "$($jdk.FullName)\bin;$sdk\bin;$env:PATH"
$key = "$env:USERPROFILE\.connectiq\developer_key.der"
$device = 'instinct3solar45mm'

Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force bin | Out-Null
    & "$sdk\bin\monkeyc.bat" -f monkey.jungle -d $device -y $key -o bin\BreezUp.prg -w
    if ($LASTEXITCODE -ne 0) { throw "monkeyc failed ($LASTEXITCODE)" }
    if ($Run) {
        if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) {
            Start-Process "$sdk\bin\simulator.exe"
            Start-Sleep -Seconds 5
        }
        & "$sdk\bin\monkeydo.bat" bin\BreezUp.prg $device
    }
} finally {
    Pop-Location
}
