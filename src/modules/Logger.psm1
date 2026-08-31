Set-StrictMode -Version Latest
$script:LogPath = $null
function Initialize-DiscoveryLogger { param([string]$Path) $script:LogPath = $Path; New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null }
function Write-DiscoveryLog { param([string]$Module,[string]$Message,[string]$Level = 'INFO') if ($script:LogPath) { $safe = $Message -replace '(?i)(password|pwd|pass|secret|token|credential)\s*[:=]\s*[^;\s]+','$1=[REDACTED]'; Add-Content -LiteralPath $script:LogPath -Value ("{0} [{1}] {2}: {3}" -f (Get-Date -Format s),$Level,$Module,$safe) } }
Export-ModuleMember -Function Initialize-DiscoveryLogger,Write-DiscoveryLog
