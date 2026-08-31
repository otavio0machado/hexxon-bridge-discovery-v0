$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\modules\PrivacySanitizer.psm1') -Force
Import-Module (Join-Path $root 'src\modules\NetworkConnections.psm1') -Force
Import-Module (Join-Path $root 'src\modules\OdbcDiscovery.psm1') -Force
Import-Module (Join-Path $root 'src\modules\Logger.psm1') -Force
Import-Module (Join-Path $root 'src\modules\ReportGenerator.psm1') -Force
function Assert-Equal {param($Actual,$Expected,[string]$Name)if($Actual -ne $Expected){throw "FAIL: $Name. Expected [$Expected], got [$Actual]"};Write-Host "PASS: $Name" -ForegroundColor Green}
Assert-Equal (Protect-DiscoveryText 'password=abc123') 'password=[REDACTED]' 'password is redacted'
Assert-Equal (Protect-DiscoveryText 'pwd=xyz;token=abcd') 'pwd=[REDACTED];token=[REDACTED]' 'pwd and token are redacted'
$safeObject=ConvertTo-SafeObject ([pscustomobject]@{server='LABSERVER';token='nao-vazar'});Assert-Equal $safeObject.token '[REDACTED]' 'object secret is redacted'
$line='  TCP    192.168.1.25:51232   192.168.1.10:3050   ESTABLISHED   4242';$p=ConvertFrom-NetstatLine $line;Assert-Equal $p.remoteAddress '192.168.1.10' 'netstat remote address';Assert-Equal $p.remotePort 3050 'netstat remote port';Assert-Equal $p.pid 4242 'netstat PID'
$odbc=Get-SafeOdbcSettings ([pscustomobject]@{server='LABSERVER';database='COMPULAB';pwd='nao-coletar'});Assert-Equal $odbc.server 'LABSERVER' 'ODBC server parsing';Assert-Equal ($odbc.PSObject.Properties.Name -contains 'pwd') $false 'ODBC secret is not collected'
$dir=Join-Path ([IO.Path]::GetTempPath()) ('hexxon-test-'+[guid]::NewGuid());New-Item -ItemType Directory -Path $dir|Out-Null;try{[IO.File]::WriteAllText((Join-Path $dir 'sample.ini'),"server=LABSERVER`r`npassword=nope`r`ndatabase=COMPULAB");$h=Get-SafeConfigurationHints (Join-Path $dir 'sample.ini');Assert-Equal @($h).Count 2 'only allowed non-secret config settings';Assert-Equal $h[0].key 'server' 'config server parsing'}finally{Remove-Item -LiteralPath $dir -Recurse -Force}
$reportRoot=Join-Path ([IO.Path]::GetTempPath()) ('hexxon-report-'+[guid]::NewGuid());try{$data=[ordered]@{system=[pscustomobject]@{hostname='TEST';};selectedApplication=[pscustomobject]@{friendlyName='Compulab';};network=[pscustomobject]@{};observedConnections=@();remoteEndpoints=@();odbc=@();databaseDrivers=@();networkShares=@();relatedServices=@();configurationHints=@();architectureInference=[pscustomobject]@{likelyServer=$null;possibleTechnologies=@();portHypotheses=@();confidence='LOW';statement='Teste'};warnings=@()};$report=New-DiscoveryReport -Data $data -ReportsRoot $reportRoot;Assert-Equal (Test-Path -LiteralPath (Join-Path $report.directory 'report.json')) $true 'JSON report generated';Assert-Equal (Test-Path -LiteralPath $report.zip) $true 'ZIP report generated'}finally{if(Test-Path -LiteralPath $reportRoot){Remove-Item -LiteralPath $reportRoot -Recurse -Force}}
Write-Host 'All tests passed.' -ForegroundColor Green
