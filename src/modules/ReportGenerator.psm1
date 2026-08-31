Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'LocalPathSafety.psm1')

function ConvertTo-HtmlSafe {
    param([AllowNull()][object]$Value)
    return [System.Security.SecurityElement]::Escape([string]$Value)
}

function New-DiscoveryReport {
    param([System.Collections.IDictionary]$Data, [string]$ReportsRoot)

    Assert-LocalFixedPath -Path $ReportsRoot -Purpose 'geração de relatório' | Out-Null
    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $dir = Join-Path $ReportsRoot $stamp
    $logs = Join-Path $dir 'logs'
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    Initialize-DiscoveryLogger (Join-Path $logs 'discovery.log')
    Write-DiscoveryLog 'ReportGenerator' 'Generating sanitized report.'
    Write-DiscoveryLog 'ProcessDiscovery' ('Identification status: {0}.' -f $Data.applicationIdentification.status)
    Write-DiscoveryLog 'SystemInfo' 'Completed local collection.'
    Write-DiscoveryLog 'NetworkConnections' ('Completed with {0} unique connection(s).' -f @($Data.observedConnections).Count)
    Write-DiscoveryLog 'OdbcDiscovery' ('Completed with {0} item(s).' -f @($Data.odbc).Count)
    Write-DiscoveryLog 'DriverDiscovery' ('Completed with {0} item(s).' -f @($Data.databaseDrivers).Count)
    Write-DiscoveryLog 'ShareDiscovery' ('Completed with {0} item(s).' -f @($Data.networkShares).Count)
    Write-DiscoveryLog 'ServiceDiscovery' ('Completed with {0} item(s).' -f @($Data.relatedServices).Count)
    Write-DiscoveryLog 'ConfigDiscovery' ('Completed with {0} sanitized hint(s).' -f @($Data.configurationHints).Count)
    foreach ($warning in @($Data.warnings)) { Write-DiscoveryLog 'Collection' $warning 'WARN' }

    $report = [ordered]@{
        schemaVersion = '1.2'
        agentVersion = '0.3.0'
        generatedAt = (Get-Date).ToString('o')
        system = $Data.system
        selectedApplication = $Data.selectedApplication
        applicationIdentification = $Data.applicationIdentification
        network = $Data.network
        observedConnections = @($Data.observedConnections)
        remoteEndpoints = @($Data.remoteEndpoints)
        odbc = @($Data.odbc)
        databaseDrivers = @($Data.databaseDrivers)
        networkShares = @($Data.networkShares)
        relatedServices = @($Data.relatedServices)
        configurationHints = @($Data.configurationHints)
        architectureInference = $Data.architectureInference
        warnings = @($Data.warnings)
        safetyPrivacy = 'Somente leitura local. Sem dados clínicos, segredos, upload, autenticação ou alteração de sistemas.'
    }

    $safe = ConvertTo-SafeObject $report
    $json = $safe | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText((Join-Path $dir 'report.json'), $json, [Text.Encoding]::UTF8)

    $inference = $safe.architectureInference
    $server = if ($inference.likelyServer) { $inference.likelyServer.hostname + ' ' + $inference.likelyServer.ip } else { 'Não identificado' }
    $application = if ($safe.selectedApplication) { $safe.selectedApplication.friendlyName } else { 'Não identificado — relatório parcial' }
    $computer = try { if ($safe.system.hostname) { $safe.system.hostname } else { 'Indisponível' } } catch { 'Indisponível' }
    $connectionCount = @($safe.observedConnections).Count
    $html = "<!doctype html><html lang='pt-BR'><meta charset='utf-8'><title>Hexxon Discovery</title><style>body{font:15px Segoe UI,Arial;background:#faf9f7;color:#251b35;margin:40px}h1{color:#35135c}h2{border-bottom:2px solid #d9cdea;padding-bottom:6px}.card{background:white;padding:20px;margin:16px 0;border-radius:8px;box-shadow:0 1px 5px #ddd}pre{white-space:pre-wrap;word-break:break-word}.good{color:#167347}</style><h1>HEXXON Bridge Discovery</h1><p>Relatório técnico local e sanitizado — Agent 0.3.0</p><div class='card'><h2>Resumo executivo</h2><p><b>Aplicação:</b> $(ConvertTo-HtmlSafe $application)<br><b>Identificação:</b> $(ConvertTo-HtmlSafe $safe.applicationIdentification.status)<br><b>Servidor provável:</b> $(ConvertTo-HtmlSafe $server)<br><b>Confiança:</b> $(ConvertTo-HtmlSafe $inference.confidence)<br><b>Conexões observadas:</b> $connectionCount</p></div><div class='card'><h2>Identificação automática</h2><pre>$(ConvertTo-HtmlSafe ($safe.applicationIdentification | ConvertTo-Json -Depth 7))</pre></div><div class='card'><h2>Inferência de arquitetura</h2><p>$(ConvertTo-HtmlSafe $inference.statement)</p><pre>$(ConvertTo-HtmlSafe ($inference | ConvertTo-Json -Depth 6))</pre></div><div class='card'><h2>Dados técnicos</h2><pre>$(ConvertTo-HtmlSafe $json)</pre></div><div class='card'><h2>Segurança e privacidade</h2><p>Somente leitura local. Nenhum dado clínico ou segredo é incluído; não há upload ou conexão com serviços externos.</p></div></html>"
    [IO.File]::WriteAllText((Join-Path $dir 'report.html'), $html, [Text.Encoding]::UTF8)

    $summary = "HEXXON BRIDGE DISCOVERY`r`n=======================`r`n`r`nComputador: $computer`r`nAplicação: $application`r`nIdentificação automática: $($safe.applicationIdentification.status)`r`nServidor provável: $server`r`nConexões observadas: $connectionCount`r`nTecnologias possíveis: $($inference.possibleTechnologies -join ', ')`r`nConfiança: $($inference.confidence)`r`n`r`nPróximo passo recomendado: enviar este ZIP ao responsável técnico para avaliação.`r`n"
    [IO.File]::WriteAllText((Join-Path $dir 'summary.txt'), $summary, [Text.Encoding]::UTF8)

    Write-DiscoveryLog 'ReportGenerator' 'Report created successfully.'
    $zip = Join-Path $ReportsRoot ('HexxonDiscoveryReport_' + $stamp + '.zip')
    Compress-Archive -Path (Join-Path $dir '*') -DestinationPath $zip -Force
    return [pscustomobject]@{ directory = $dir; zip = $zip }
}

Export-ModuleMember -Function New-DiscoveryReport
