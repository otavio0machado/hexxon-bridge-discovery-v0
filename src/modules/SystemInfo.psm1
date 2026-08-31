Set-StrictMode -Version Latest
function Get-DiscoverySystemInfo {
 $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
 $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
 $adapters=@(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{name=$_.Description; ipv4=@($_.IPAddress | Where-Object {$_ -match '^\d{1,3}(\.\d{1,3}){3}$'}); subnet=@($_.IPSubnet | Where-Object {$_ -match '^\d{1,3}(\.\d{1,3}){3}$'}); gateway=@($_.DefaultIPGateway); dns=@($_.DNSServerSearchOrder)} })
 [pscustomobject]@{hostname=$env:COMPUTERNAME; windowsVersion=if($os){$os.Caption+' '+$os.Version}else{'Unavailable'}; architecture=$env:PROCESSOR_ARCHITECTURE; powerShellVersion=$PSVersionTable.PSVersion.ToString(); accountType=if($cs -and $cs.PartOfDomain){'domain'}else{'local_or_workgroup'}; partOfDomain=if($cs){[bool]$cs.PartOfDomain}else{$false}; interfaces=$adapters; machineTime=(Get-Date).ToString('o'); timezone=(Get-TimeZone).Id}
}
Export-ModuleMember -Function Get-DiscoverySystemInfo
