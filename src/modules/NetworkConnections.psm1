Set-StrictMode -Version Latest
function ConvertFrom-NetstatLine { param([string]$Line) if($Line -notmatch '^\s*TCP\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s*$'){return $null};$l=$Matches[1];$r=$Matches[2];$lp=[int]($l -replace '^.*:','');$rp=[int]($r -replace '^.*:','');[pscustomobject]@{localAddress=($l -replace ':[^:]+$','');localPort=$lp;remoteAddress=($r -replace ':[^:]+$','');remotePort=$rp;state=$Matches[3];pid=[int]$Matches[4];source='netstat_metadata'} }
function Get-ProcessConnections { param([int]$ProcessId)
 $result=@();$cmd=Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
 if($cmd){try{$result=@(Get-NetTCPConnection -OwningProcess $ProcessId -ErrorAction Stop | ForEach-Object {[pscustomobject]@{localAddress=$_.LocalAddress;localPort=$_.LocalPort;remoteAddress=$_.RemoteAddress;remotePort=$_.RemotePort;state=$_.State.ToString();pid=$ProcessId;source='Get-NetTCPConnection'}})}catch{}}
 if(!$result){$result=@((& netstat -ano -p tcp 2>$null | ForEach-Object {ConvertFrom-NetstatLine $_}) | Where-Object {$null -ne $_ -and $_.pid -eq $ProcessId})}
 return @($result | Where-Object {$_.remoteAddress -and $_.remoteAddress -notin @('0.0.0.0','::','*')} | Sort-Object remoteAddress,remotePort -Unique)
}
function Get-RemoteEndpointMetadata { param([object[]]$Connections) $items=@(); foreach($c in ($Connections | Sort-Object remoteAddress,remotePort -Unique)){ $items += [pscustomobject]@{ip=$c.remoteAddress;hostname=$null;port=$c.remotePort;source='observed_tcp_connection';confidence='CONFIRMED'} };return @($items) }
Export-ModuleMember -Function ConvertFrom-NetstatLine,Get-ProcessConnections,Get-RemoteEndpointMetadata
