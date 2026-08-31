$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
@('PrivacySanitizer','NetworkConnections','OdbcDiscovery','ProcessDiscovery','ArchitectureInference','Logger','ReportGenerator') | ForEach-Object {
    Import-Module (Join-Path $root ('src\modules\' + $_ + '.psm1')) -Force
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Name)
    if ($Actual -ne $Expected) { throw "FAIL: $Name. Expected [$Expected], got [$Actual]" }
    Write-Host "PASS: $Name" -ForegroundColor Green
}

function New-FakeProcess {
    param([int]$ProcessId, [string]$Name, [string]$Product = '', [string]$Publisher = '', [string]$WindowTitle = '', [int]$ParentId = 0)
    return [pscustomobject]@{ friendlyName = $Name; executableName = $Name + '.exe'; pid = $ProcessId; parentPid = $ParentId; path = 'C:\Apps\' + $Name + '.exe'; fileVersion = '1.0'; publisher = $Publisher; productName = $Product; fileDescription = $Product; windowTitle = $WindowTitle; signatureSubject = $null }
}

Assert-Equal (Protect-DiscoveryText 'password=abc123') 'password=[REDACTED]' 'password is redacted'
Assert-Equal (Protect-DiscoveryText 'pwd=xyz;token=abcd') 'pwd=[REDACTED];token=[REDACTED]' 'pwd and token are redacted'
$safeObject = ConvertTo-SafeObject ([pscustomobject]@{ server = 'LABSERVER'; token = 'nao-vazar' })
Assert-Equal $safeObject.token '[REDACTED]' 'object secret is redacted'

$line = '  TCP    192.168.1.25:51232   192.168.1.10:3050   ESTABLISHED   4242'
$parsed = ConvertFrom-NetstatLine $line
Assert-Equal $parsed.remoteAddress '192.168.1.10' 'netstat remote address'
Assert-Equal $parsed.remotePort 3050 'netstat remote port'
Assert-Equal $parsed.pid 4242 'netstat PID'

$odbc = Get-SafeOdbcSettings ([pscustomobject]@{ server = 'LABSERVER'; database = 'COMPULAB'; pwd = 'nao-coletar' })
Assert-Equal $odbc.server 'LABSERVER' 'ODBC server parsing'
Assert-Equal ($odbc.PSObject.Properties.Name -contains 'pwd') $false 'ODBC secret is not collected'

$strong = Get-CompulabIdentityScore -Process (New-FakeProcess 10 'appmain' 'Compulab' 'Performática' 'Compulab')
Assert-Equal ((Select-CompulabCandidate @($strong)).status) 'found' 'strong product metadata is auto-identified'
$generic = Get-CompulabIdentityScore -Process (New-FakeProcess 11 'lab-helper' 'Laboratório genérico')
Assert-Equal ((Select-CompulabCandidate @($generic)).status) 'not_found' 'generic lab process is not selected'
$newVisible = Get-CompulabIdentityScore -Process (New-FakeProcess 12 'unknown-client' '' '' 'Sistema principal') -BaselineProcessIds @(1,2,3)
Assert-Equal ((Select-CompulabCandidate @($newVisible)).status) 'found' 'unique new visible process can be identified'
$ambiguous = Select-CompulabCandidate @([pscustomobject]@{ score = 100; application = New-FakeProcess 20 'candidate-a' }, [pscustomobject]@{ score = 90; application = New-FakeProcess 21 'candidate-b' })
Assert-Equal $ambiguous.status 'ambiguous' 'similar candidates are rejected as ambiguous'
$tree = @((New-FakeProcess 30 'main'), (New-FakeProcess 31 'child' -ParentId 30), (New-FakeProcess 32 'grandchild' -ParentId 31))
Assert-Equal (@(Get-RelatedProcessIds -RootPid 30 -Snapshot $tree).Count) 3 'child process tree is monitored'

$emptyInference = Get-ArchitectureInference -Endpoints @() -Drivers @() -Hints @()
Assert-Equal $emptyInference.confidence 'LOW' 'empty evidence produces safe low-confidence inference'

$configDirectory = Join-Path ([IO.Path]::GetTempPath()) ('hexxon-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $configDirectory | Out-Null
try {
    [IO.File]::WriteAllText((Join-Path $configDirectory 'sample.ini'), "server=LABSERVER`r`npassword=nope`r`ndatabase=COMPULAB")
    $hints = Get-SafeConfigurationHints (Join-Path $configDirectory 'sample.ini')
    Assert-Equal @($hints).Count 2 'only allowed non-secret config settings'
    Assert-Equal $hints[0].key 'server' 'config server parsing'
} finally { Remove-Item -LiteralPath $configDirectory -Recurse -Force }

$reportRoot = Join-Path ([IO.Path]::GetTempPath()) ('hexxon-report-' + [guid]::NewGuid())
try {
    $identity = [pscustomobject]@{ status = 'not_found'; selected = $null; ranked = @(); reason = 'Test'; monitoredPids = @(); source = 'test' }
    $data = [ordered]@{ system = [pscustomobject]@{ hostname = 'TEST' }; selectedApplication = $null; applicationIdentification = $identity; network = [pscustomobject]@{}; observedConnections = @(); remoteEndpoints = @(); odbc = @(); databaseDrivers = @(); networkShares = @(); relatedServices = @(); configurationHints = @(); architectureInference = $emptyInference; warnings = @('Relatório parcial de teste') }
    $report = New-DiscoveryReport -Data $data -ReportsRoot $reportRoot
    Assert-Equal (Test-Path -LiteralPath (Join-Path $report.directory 'report.json')) $true 'partial JSON report generated'
    Assert-Equal (Test-Path -LiteralPath $report.zip) $true 'partial ZIP report generated'
    $json = Get-Content -LiteralPath (Join-Path $report.directory 'report.json') -Raw | ConvertFrom-Json
    Assert-Equal $json.agentVersion '0.2.0' 'report uses current agent version'
    Assert-Equal $json.applicationIdentification.status 'not_found' 'partial report records automatic identification outcome'
} finally { if (Test-Path -LiteralPath $reportRoot) { Remove-Item -LiteralPath $reportRoot -Recurse -Force } }

$headlessRoot = Join-Path ([IO.Path]::GetTempPath()) ('hexxon-headless-' + [guid]::NewGuid())
try {
    $headlessReport = & (Join-Path $root 'src\HexxonDiscovery.ps1') -Mock -Headless -ReportsRoot $headlessRoot
    Assert-Equal (Test-Path -LiteralPath $headlessReport.zip) $true 'headless mock completes and generates ZIP'
} finally { if (Test-Path -LiteralPath $headlessRoot) { Remove-Item -LiteralPath $headlessRoot -Recurse -Force } }

Write-Host 'All tests passed.' -ForegroundColor Green
