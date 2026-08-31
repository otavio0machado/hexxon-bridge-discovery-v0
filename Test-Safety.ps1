$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Get-ChildItem -Path (Join-Path $root 'src') -Recurse -File | Where-Object {$_.Extension -in '.ps1','.psm1'}
$writeSql=@('IN'+'SERT','UP'+'DATE','DEL'+'ETE','DR'+'OP','AL'+'TER','TRUN'+'CATE')
$terms=@('Invoke-WebRequest','Invoke-RestMethod','WebClient','HttpClient','Enter-PSSession','New-PSSession','Invoke-Command','Stop-Process','Stop-Service','Set-Service','Set-NetFirewallRule','New-NetFirewallRule','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty','Remove-Item','Remove-SmbMapping','New-SmbMapping','Test-NetConnection','TcpClient','UdpClient','Socket')
$issues=@();foreach($file in $source){$n=0;foreach($line in Get-Content -LiteralPath $file.FullName){$n++;foreach($term in $terms){if($line -match [regex]::Escape($term)){$issues += ('{0}:{1}: prohibited or review-required API {2}' -f $file.FullName,$n,$term)}};foreach($term in $writeSql){if($line -match ('(?i)\b'+[regex]::Escape($term)+'\b')){$issues += ('{0}:{1}: prohibited SQL write keyword {2}' -f $file.FullName,$n,$term)}}}}
if($issues){$issues|ForEach-Object{Write-Host $_ -ForegroundColor Red};throw 'Safety test failed.'}
Write-Host 'Safety test passed: no external-call, remote-management, active-probing or system-modification APIs found in production source.' -ForegroundColor Green
