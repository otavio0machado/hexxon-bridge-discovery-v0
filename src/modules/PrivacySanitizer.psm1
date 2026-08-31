Set-StrictMode -Version Latest
$script:SecretPattern = '(?i)\b(password|pwd|pass|secret|token|credential|userpassword|api[_-]?key)\b'
$script:AllowedSettingPattern = '(?i)^\s*(server|host|hostname|ip|port|database|db|datasource|data\s*source|catalog|driver|protocol)\s*[:=]'
function Protect-DiscoveryText {
 param([AllowNull()][string]$Text)
 if ($null -eq $Text) { return $null }
 return [regex]::Replace($Text,'(?im)(\b(?:password|pwd|pass|secret|token|credential|userpassword|api[_-]?key)\b\s*[:=]\s*)([^\r\n;]*)','$1[REDACTED]')
}
function Get-SafeConfigurationHints {
 param([string]$Path,[int]$MaxBytes = 2097152)
 $hints = @()
 try {
   $item = Get-Item -LiteralPath $Path -ErrorAction Stop
   if ($item.Length -gt $MaxBytes) { return @() }
   foreach ($line in [System.IO.File]::ReadLines($Path)) {
     if ($line -match $script:SecretPattern) { continue }
     if ($line -match $script:AllowedSettingPattern) {
       $parts = $line -split '[:=]',2
       if ($parts.Count -eq 2) { $hints += [pscustomobject]@{ configFile=$Path; key=$parts[0].Trim(); value=(Protect-DiscoveryText $parts[1].Trim()); source='local_config'; confidence='HIGH' } }
     }
   }
 } catch { }
 return @($hints)
}
function ConvertTo-SafeObject {
 param([object]$InputObject)
 if ($null -eq $InputObject) { return $null }
 if ($InputObject -is [string]) { return (Protect-DiscoveryText $InputObject) }
 if ($InputObject -is [System.Collections.IDictionary]) { $copy=[ordered]@{}; foreach($key in $InputObject.Keys){ if ($key -match $script:SecretPattern){$copy[$key]='[REDACTED]'}else{$copy[$key]=ConvertTo-SafeObject $InputObject[$key]} }; return [pscustomobject]$copy }
 if ($InputObject -is [psobject]) { $copy=[ordered]@{}; foreach($property in $InputObject.PSObject.Properties){ if ($property.Name -match $script:SecretPattern){$copy[$property.Name]='[REDACTED]'}else{$copy[$property.Name]=ConvertTo-SafeObject $property.Value} }; return [pscustomobject]$copy }
 if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) { return @($InputObject | ForEach-Object { ConvertTo-SafeObject $_ }) }
 return $InputObject
}
Export-ModuleMember -Function Protect-DiscoveryText,Get-SafeConfigurationHints,ConvertTo-SafeObject
