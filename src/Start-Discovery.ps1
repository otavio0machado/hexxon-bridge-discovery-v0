$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
try {
    & (Join-Path $PSScriptRoot 'HexxonDiscovery.ps1')
} catch {
    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
        $logDirectory = Join-Path (Join-Path $root 'reports') ('startup_' + $stamp)
        New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
        $safeMessage = [regex]::Replace([string]$_.Exception.Message, '(?i)(password|pwd|pass|secret|token|credential)\s*[:=]\s*[^;\s]+', '$1=[REDACTED]')
        [IO.File]::WriteAllText((Join-Path $logDirectory 'startup-error.log'), ((Get-Date -Format s) + ' Startup error: ' + $safeMessage), [Text.Encoding]::UTF8)
    } catch { }
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("O Hexxon Discovery não conseguiu iniciar corretamente.`nNada foi alterado.`nFeche esta mensagem e envie a pasta reports ao responsável.", 'Hexxon Discovery', 'OK', 'Error') | Out-Null
    } catch { }
}
