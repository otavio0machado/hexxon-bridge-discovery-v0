Set-StrictMode -Version Latest
function Get-DiscoveryProcesses {
 $terms='compulab|performatica|laboratório|laboratorio|lab'
 $items=@()
 foreach($p in Get-Process -ErrorAction SilentlyContinue){
  try{$path=$p.Path}catch{$path=$null}; $name=$p.ProcessName
  if(($name+' '+$path) -match $terms){$v=$null;try{if($path){$v=[Diagnostics.FileVersionInfo]::GetVersionInfo($path)}}catch{};$items += [pscustomobject]@{friendlyName=if($v -and $v.ProductName){$v.ProductName}else{$name}; executableName=if($path){[IO.Path]::GetFileName($path)}else{$name+'.exe'}; pid=$p.Id; path=$path; fileVersion=if($v){$v.FileVersion}else{$null}; publisher=if($v){$v.CompanyName}else{$null}; productName=if($v){$v.ProductName}else{$null}; fileDescription=if($v){$v.FileDescription}else{$null}; matchStrength=if(($name+' '+$path) -match 'compulab|performatica'){'strong'}else{'candidate'}}}
 }
 return @($items | Sort-Object @{Expression={$_.matchStrength -eq 'strong'};Descending=$true},friendlyName)
}
function Get-DiscoveryAllProcesses { return @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { try{$path=$_.Path}catch{$path=$null}; [pscustomobject]@{friendlyName=$_.ProcessName;executableName=if($path){[IO.Path]::GetFileName($path)}else{$_.ProcessName+'.exe'};pid=$_.Id;path=$path;fileVersion=$null;publisher=$null;productName=$null;fileDescription=$null;matchStrength='manual'} } | Sort-Object friendlyName) }
Export-ModuleMember -Function Get-DiscoveryProcesses,Get-DiscoveryAllProcesses
