[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$sourceRoot = Join-Path $root 'src'
$testRoot = Join-Path $root 'tests'
$executableExtensions = @('.ps1','.psm1','.bat','.cmd','.vbs','.js')
$allExecutableFiles = @(Get-ChildItem -Path $root -Recurse -File | Where-Object { $_.Extension -in $executableExtensions -and $_.FullName -notmatch '[\\/]\.git[\\/]|[\\/]reports[\\/]' })
$productionFiles = @($allExecutableFiles | Where-Object { -not $_.FullName.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase) -and $_.Name -ne 'Test-Safety.ps1' })
$testAndGateFiles = @($allExecutableFiles | Where-Object { $_.FullName.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase) -or $_.Name -eq 'Test-Safety.ps1' })

$writeSql = @('IN'+'SERT','UP'+'DATE','DEL'+'ETE','DR'+'OP','AL'+'TER','TRUN'+'CATE')
$prohibitedTerms = @('Invoke-WebRequest','Invoke-RestMethod','WebClient','HttpClient','Enter-PSSession','New-PSSession','Invoke-Command','Stop-Process','Stop-Service','Set-Service','Set-NetFirewallRule','New-NetFirewallRule','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty','Remove-Item','Remove-SmbMapping','New-SmbMapping','Test-NetConnection','TcpClient','UdpClient','Socket','GetHostEntry','XMLHTTP','WScript.Shell','ADODB')
$issues = @()
foreach ($file in $productionFiles) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        foreach ($term in $prohibitedTerms) { if ($line -match [regex]::Escape($term)) { $issues += ('{0}:{1}: prohibited or review-required capability {2}' -f $file.FullName,$lineNumber,$term) } }
        foreach ($term in $writeSql) { if ($line -match ('(?i)\b'+[regex]::Escape($term)+'\b')) { $issues += ('{0}:{1}: prohibited SQL write keyword {2}' -f $file.FullName,$lineNumber,$term) } }
    }
}

$testCommandProhibited = @($prohibitedTerms | Where-Object { $_ -notin @('Remove-Item','Socket','GetHostEntry','XMLHTTP','WScript.Shell','ADODB') })
foreach ($file in @($testAndGateFiles | Where-Object { $_.Extension -in '.ps1','.psm1' })) {
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($command in @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))) {
        $commandName = $command.GetCommandName()
        if ($commandName -and $commandName -in $testCommandProhibited) { $issues += ('{0}:{1}: prohibited command invocation in test/gate code: {2}' -f $file.FullName,$command.Extent.StartLineNumber,$commandName) }
    }
}

$launcherPath = Join-Path $root 'INICIAR_DISCOVERY.bat'
$launcher = Get-Content -LiteralPath $launcherPath -Raw
$batchPatterns = @('(?im)^\s*(del|erase|format|shutdown)\b','(?im)\b(reg\s+(add|delete)|sc\s+(stop|config)|curl|wget|certutil|bitsadmin)\b')
foreach ($batchFile in @($allExecutableFiles | Where-Object { $_.Extension -in '.bat','.cmd' })) { $batchContent = Get-Content -LiteralPath $batchFile.FullName -Raw; foreach ($pattern in $batchPatterns) { if ($batchContent -match $pattern) { $issues += ($batchFile.FullName + ' contains prohibited command pattern: ' + $pattern) } } }
if ($launcher -notmatch 'Start-Discovery\.ps1') { $issues += 'Launcher does not call the guarded startup wrapper.' }

$startup = Get-Content -LiteralPath (Join-Path $sourceRoot 'Start-Discovery.ps1') -Raw
if ($startup -notmatch 'Test-Safety\.ps1') { $issues += 'Startup wrapper does not execute the safety gate.' }
if ($startup -notmatch 'Test-IsLocalFixedPath') { $issues += 'Startup error logging lacks local fixed-drive enforcement.' }
$mainSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'HexxonDiscovery.ps1') -Raw
foreach ($manualSelectionTerm in @('ProcessBox','Selecionar outro','Get-DiscoveryAllProcesses')) { if ($mainSource -match [regex]::Escape($manualSelectionTerm)) { $issues += ('Manual process selection remains: ' + $manualSelectionTerm) } }
$processSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'modules\ProcessDiscovery.psm1') -Raw
if ($processSource -match '(?im)^\s*windowTitle\s*=') { $issues += 'Raw window title is retained in a process object.' }
if ($processSource -notmatch 'hasStrongIdentityEvidence') { $issues += 'Process selection does not enforce strong identity evidence.' }
$configSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'modules\ConfigDiscovery.psm1') -Raw
if ($configSource -notmatch 'Test-IsLocalFixedPath') { $issues += 'Configuration discovery lacks local fixed-drive enforcement.' }
$reportSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'modules\ReportGenerator.psm1') -Raw
if ($reportSource -notmatch 'Assert-LocalFixedPath') { $issues += 'Report generation lacks local fixed-drive enforcement.' }

foreach ($file in $allExecutableFiles) {
    $raw = Get-Content -LiteralPath $file.FullName -Raw
    if ($raw -match '(?is)param\s*\([^)]*\$Pid\b') { $issues += ('Reserved automatic variable used as a parameter in ' + $file.FullName) }
}

if ($issues) { $issues | ForEach-Object { Write-Host $_ -ForegroundColor Red }; throw 'Safety test failed.' }
if (-not $Quiet) { Write-Host ("Safety gate passed: {0} executable file(s) inspected; production capabilities, launcher, privacy and local-path invariants verified." -f $allExecutableFiles.Count) -ForegroundColor Green }
