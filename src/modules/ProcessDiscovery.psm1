Set-StrictMode -Version Latest

$script:StrongIdentityPattern = '(?i)compulab|perform[aá]tica'
$script:ProductIdentityPattern = '(?i)laborat[oó]rio|sistema\s+lab|gest[aã]o\s+lab'

function Get-DiscoveryProcessIds {
    return @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.Id })
}

function Get-InstalledCompulabHints {
    $hints = @()
    $roots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $roots) {
        try {
            foreach ($item in @(Get-ItemProperty -Path $root -ErrorAction SilentlyContinue)) {
                $identity = '{0} {1} {2}' -f $item.DisplayName, $item.Publisher, $item.InstallLocation
                if ($identity -match $script:StrongIdentityPattern) {
                    $hints += [pscustomobject]@{ displayName = [string]$item.DisplayName; publisher = [string]$item.Publisher; installLocation = [string]$item.InstallLocation; source = 'local_installed_product_registry' }
                }
            }
        } catch { }
    }
    return @($hints | Sort-Object displayName, installLocation -Unique)
}

function Get-DiscoveryProcessSnapshot {
    $wmiByPid = @{}
    try { foreach ($item in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) { $wmiByPid[[int]$item.ProcessId] = $item } } catch { }
    $items = @()
    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        try { $processId = [int]$process.Id; $processName = [string]$process.ProcessName } catch { continue }
        $path = $null; $versionInfo = $null
        $windowTitle = $null
        try { $path = $process.Path } catch { }
        try { $windowTitle = [string]$process.MainWindowTitle } catch { }
        try { if ($path) { $versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($path) } } catch { }
        $parentPid = $null
        if ($wmiByPid.ContainsKey($processId)) {
            $parentPid = [int]$wmiByPid[$processId].ParentProcessId
            if (-not $path) { $path = [string]$wmiByPid[$processId].ExecutablePath }
        }
        $signatureSubject = $null
        $preliminaryIdentity = '{0} {1} {2} {3}' -f $processName, $path, $(if ($versionInfo) { $versionInfo.CompanyName } else { '' }), $(if ($versionInfo) { $versionInfo.ProductName } else { '' })
        if ($path -and $preliminaryIdentity -match $script:StrongIdentityPattern) {
            try {
                $signature = Get-AuthenticodeSignature -FilePath $path -ErrorAction SilentlyContinue
                if ($signature -and $signature.SignerCertificate) { $signatureSubject = [string]$signature.SignerCertificate.Subject }
            } catch { }
        }
        $items += [pscustomobject]@{
            friendlyName = if ($versionInfo -and $versionInfo.ProductName) { $versionInfo.ProductName } else { $processName }
            executableName = if ($path) { [IO.Path]::GetFileName($path) } else { $processName + '.exe' }
            pid = $processId; parentPid = $parentPid; path = $path
            fileVersion = if ($versionInfo) { $versionInfo.FileVersion } else { $null }
            publisher = if ($versionInfo) { $versionInfo.CompanyName } else { $null }
            productName = if ($versionInfo) { $versionInfo.ProductName } else { $null }
            fileDescription = if ($versionInfo) { $versionInfo.FileDescription } else { $null }
            windowTitle = $windowTitle
            signatureSubject = $signatureSubject
        }
    }
    return @($items)
}

function Get-CompulabIdentityScore {
    param([Parameter(Mandatory = $true)][object]$Process, [int[]]$BaselineProcessIds = @(), [object[]]$InstalledHints = @())
    $score = 0; $evidence = @()
    $signatureSubject = if ($Process.PSObject.Properties.Name -contains 'signatureSubject') { $Process.signatureSubject } else { $null }
    $strongFields = '{0} {1} {2} {3} {4} {5} {6}' -f $Process.executableName, $Process.path, $Process.publisher, $Process.productName, $Process.fileDescription, $Process.windowTitle, $signatureSubject
    if ($strongFields -match '(?i)compulab') { $score += 100; $evidence += 'nome ou metadado contém Compulab' }
    if ($strongFields -match '(?i)perform[aá]tica') { $score += 80; $evidence += 'fabricante ou metadado contém Performática' }
    if ($strongFields -match $script:ProductIdentityPattern) { $score += 20; $evidence += 'metadado relacionado a sistema laboratorial' }
    foreach ($hint in @($InstalledHints)) {
        if ($hint.installLocation -and $Process.path -and $Process.path.StartsWith($hint.installLocation, [StringComparison]::OrdinalIgnoreCase)) {
            $score += 70; $evidence += 'executável está no diretório de produto Compulab/Performática instalado'; break
        }
    }
    $isNew = $BaselineProcessIds.Count -gt 0 -and [int]$Process.pid -notin $BaselineProcessIds
    if ($isNew) {
        $score += 25; $evidence += 'processo iniciado após a orientação para abrir o Compulab'
        if ($Process.windowTitle) { $score += 40; $evidence += 'novo processo possui janela visível' }
    }
    if ($Process.windowTitle -and $Process.windowTitle -match $script:StrongIdentityPattern) { $score += 30; $evidence += 'título da janela identifica o produto' }
    if ($signatureSubject -and $signatureSubject -match $script:StrongIdentityPattern) { $score += 40; $evidence += 'assinatura digital identifica o fabricante ou produto' }
    return [pscustomobject]@{ application = $Process; score = $score; evidence = @($evidence | Sort-Object -Unique); isNewProcess = $isNew }
}

function Select-CompulabCandidate {
    param([object[]]$Candidates = @())
    $ranked = @($Candidates | Where-Object { $_.score -gt 0 } | Sort-Object score -Descending)
    if ($ranked.Count -eq 0 -or $ranked[0].score -lt 60) { return [pscustomobject]@{ status = 'not_found'; selected = $null; ranked = $ranked; reason = 'Nenhuma evidência atingiu o limite seguro.' } }
    if ($ranked.Count -gt 1 -and $ranked[1].score -ge 60 -and ($ranked[0].score - $ranked[1].score) -lt 20) { return [pscustomobject]@{ status = 'ambiguous'; selected = $null; ranked = $ranked; reason = 'Dois ou mais processos possuem evidências semelhantes.' } }
    return [pscustomobject]@{ status = 'found'; selected = $ranked[0]; ranked = $ranked; reason = 'Processo identificado automaticamente por evidências locais.' }
}

function Get-RelatedProcessIds {
    param([Parameter(Mandatory = $true)][int]$RootPid, [Parameter(Mandatory = $true)][object[]]$Snapshot)
    $found = @($RootPid); $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($process in $Snapshot) {
            if ($null -ne $process.parentPid -and [int]$process.parentPid -in $found -and [int]$process.pid -notin $found) { $found += [int]$process.pid; $changed = $true }
        }
    }
    return @($found | Sort-Object -Unique)
}

function Find-CompulabProcess {
    param([int[]]$BaselineProcessIds = @())
    $snapshot = @(Get-DiscoveryProcessSnapshot); $installedHints = @(Get-InstalledCompulabHints)
    $scored = @($snapshot | ForEach-Object { Get-CompulabIdentityScore -Process $_ -BaselineProcessIds $BaselineProcessIds -InstalledHints $installedHints })
    $selection = Select-CompulabCandidate -Candidates $scored
    $monitored = if ($selection.status -eq 'found') { @(Get-RelatedProcessIds -RootPid $selection.selected.application.pid -Snapshot $snapshot) } else { @() }
    $selection | Add-Member -NotePropertyName monitoredPids -NotePropertyValue $monitored
    $selection | Add-Member -NotePropertyName source -NotePropertyValue 'automatic_local_process_identification'
    return $selection
}

function Get-DiscoveryProcesses { $result = Find-CompulabProcess; return @($result.ranked | ForEach-Object { $_.application }) }

Export-ModuleMember -Function Get-DiscoveryProcessIds,Get-InstalledCompulabHints,Get-DiscoveryProcessSnapshot,Get-CompulabIdentityScore,Select-CompulabCandidate,Get-RelatedProcessIds,Find-CompulabProcess,Get-DiscoveryProcesses
