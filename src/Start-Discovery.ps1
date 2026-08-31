[CmdletBinding()]
param(
    [switch]$Mock,
    [switch]$Headless,
    [string]$ReportsRoot,
    [ValidateRange(5,60)][int]$ObservationSeconds = 60
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
try {
    & (Join-Path $root 'Test-Safety.ps1') -Quiet
    & (Join-Path $PSScriptRoot 'HexxonDiscovery.ps1') -Mock:$Mock -Headless:$Headless -ReportsRoot $ReportsRoot -ObservationSeconds $ObservationSeconds
} catch {
    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
        Import-Module (Join-Path $PSScriptRoot 'modules\LocalPathSafety.psm1') -Force
        $reportsDirectory = Join-Path $root 'reports'
        if (Test-IsLocalFixedPath $reportsDirectory) {
            $logDirectory = Join-Path $reportsDirectory ('startup_' + $stamp)
            New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
            $safeMessage = [regex]::Replace([string]$_.Exception.Message, '(?i)(password|pwd|pass|secret|token|credential)\s*[:=]\s*[^;\s]+', '$1=[REDACTED]')
            [IO.File]::WriteAllText((Join-Path $logDirectory 'startup-error.log'), ((Get-Date -Format s) + ' Startup error: ' + $safeMessage), [Text.Encoding]::UTF8)
        }
    } catch { }
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("O Hexxon Discovery não conseguiu iniciar corretamente.`nNada foi alterado.`nFeche esta mensagem e informe o responsável.", 'Hexxon Discovery', 'OK', 'Error') | Out-Null
    } catch { }
}
