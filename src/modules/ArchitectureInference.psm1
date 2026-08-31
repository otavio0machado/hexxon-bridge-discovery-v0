Set-StrictMode -Version Latest

function Get-PortHypothesis {
    param([int]$Port)
    $map = @{ 1433 = 'Microsoft SQL Server'; 1434 = 'SQL Server Browser'; 3050 = 'Firebird database service'; 5432 = 'PostgreSQL'; 3306 = 'MySQL / MariaDB'; 1521 = 'Oracle'; 445 = 'SMB'; 139 = 'NetBIOS/SMB'; 80 = 'HTTP'; 443 = 'HTTPS'; 8080 = 'HTTP alternativo'; 8443 = 'HTTPS alternativo' }
    if ($map.ContainsKey($Port)) { return [pscustomobject]@{ port = $Port; possibleService = $map[$Port]; source = 'well_known_port'; confidence = 'MEDIUM'; evidence = 'well-known/default port' } }
    return $null
}

function Get-ArchitectureInference {
    param([object[]]$Endpoints = @(), [object[]]$Drivers = @(), [object[]]$Hints = @())
    $portEvidence = @()
    $technologies = @()
    foreach ($endpoint in @($Endpoints)) {
        $hypothesis = Get-PortHypothesis $endpoint.port
        if ($null -ne $hypothesis) { $portEvidence += $hypothesis }
    }
    foreach ($driver in @($Drivers)) {
        if ($driver.name -match 'Firebird') { $technologies += 'Firebird' }
        elseif ($driver.name -match 'PostgreSQL') { $technologies += 'PostgreSQL' }
        elseif ($driver.name -match 'SQL Server') { $technologies += 'Microsoft SQL Server' }
        elseif ($driver.name -match 'MySQL|MariaDB') { $technologies += 'MySQL / MariaDB' }
        elseif ($driver.name -match 'Oracle') { $technologies += 'Oracle' }
    }
    foreach ($hint in @($Hints)) { if ($hint.value -match 'firebird') { $technologies += 'Firebird' } }
    $server = @($Endpoints) | Select-Object -First 1
    $confidence = if ($null -ne $server) { 'MEDIUM' } else { 'LOW' }
    $hasFirebirdPort = @($portEvidence | Where-Object { $_.possibleService -eq 'Firebird database service' }).Count -gt 0
    if ($hasFirebirdPort -and $technologies -contains 'Firebird') { $confidence = 'HIGH' }
    $likelyServer = if ($null -ne $server) { [pscustomobject]@{ hostname = $server.hostname; ip = $server.ip; source = $server.source; confidence = $server.confidence } } else { $null }
    return [pscustomobject]@{ likelyServer = $likelyServer; possibleTechnologies = @($technologies | Sort-Object -Unique); portHypotheses = @($portEvidence); confidence = $confidence; statement = 'Esta é uma inferência baseada em evidências locais; não é confirmação de arquitetura.' }
}

Export-ModuleMember -Function Get-PortHypothesis,Get-ArchitectureInference
