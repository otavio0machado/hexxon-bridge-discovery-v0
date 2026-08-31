Set-StrictMode -Version Latest
function Get-DiscoveryServices {$rx='Compulab|Performatica|Firebird|SQL Server|PostgreSQL|MySQL|MariaDB|Oracle';return @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {$_.Name -match $rx -or $_.DisplayName -match $rx} | ForEach-Object {[pscustomobject]@{name=$_.Name;displayName=$_.DisplayName;state=$_.State;startMode=$_.StartMode;path=$_.PathName;source='local_service';confidence='CONFIRMED'}})}
Export-ModuleMember -Function Get-DiscoveryServices
