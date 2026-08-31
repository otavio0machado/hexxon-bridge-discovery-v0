[CmdletBinding()]
param(
    [switch]$Mock,
    [switch]$Headless,
    [string]$ReportsRoot,
    [ValidateRange(5,60)][int]$ObservationSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $PSScriptRoot 'modules'
@('Logger','PrivacySanitizer','LocalPathSafety','SystemInfo','ProcessDiscovery','NetworkConnections','OdbcDiscovery','DriverDiscovery','ShareDiscovery','ServiceDiscovery','ConfigDiscovery','ArchitectureInference','ReportGenerator') | ForEach-Object {
    Import-Module (Join-Path $moduleRoot ($_.ToString() + '.psm1')) -Force
}

function Get-MockApplication {
    return [pscustomobject]@{
        friendlyName = 'Compulab (simulado)'; executableName = 'Compulab.exe'; pid = 4242; parentPid = 100
        path = 'C:\Compulab\Compulab.exe'; fileVersion = '1.0.0'; publisher = 'Performática Demo'
        productName = 'Compulab'; fileDescription = 'Aplicação demonstrativa'; hasVisibleWindow = $true
        windowTitleMatchedCompulab = $true; windowTitleMatchedVendor = $false; signatureSubject = $null
    }
}

function Get-MockIdentification {
    $app = Get-MockApplication
    return [pscustomobject]@{
        status = 'found'; selected = [pscustomobject]@{ application = $app; score = 210; evidence = @('nome ou metadado contém Compulab','fabricante ou metadado contém Performática'); isNewProcess = $true }
        ranked = @(); reason = 'Processo simulado identificado automaticamente.'; monitoredPids = @(4242); source = 'mock_automatic_identification'
    }
}

function Get-MockData {
    $app = Get-MockApplication
    return [ordered]@{
        system = [pscustomobject]@{ hostname = 'LAB-CLIENTE-DEMO'; windowsVersion = 'Windows 11 (simulado)'; architecture = 'AMD64'; powerShellVersion = $PSVersionTable.PSVersion.ToString(); accountType = 'domain'; partOfDomain = $true; interfaces = @(); machineTime = (Get-Date).ToString('o'); timezone = 'America/Sao_Paulo' }
        selectedApplication = $app
        applicationIdentification = ConvertTo-ReportableProcessIdentification (Get-MockIdentification)
        network = [pscustomobject]@{ source = 'mock'; observation = 'TCP metadata only' }
        observedConnections = @([pscustomobject]@{ localAddress = '192.168.1.25'; localPort = 51232; remoteAddress = '192.168.1.10'; remotePort = 3050; state = 'Established'; pid = 4242; source = 'mock_observed_tcp_connection' })
        remoteEndpoints = @([pscustomobject]@{ ip = '192.168.1.10'; hostname = 'LABSERVER'; port = 3050; source = 'mock_observed_tcp_connection'; confidence = 'CONFIRMED' })
        odbc = @([pscustomobject]@{ name = 'CompulabFirebird'; scope = 'system'; driver = 'Firebird/InterBase(r) driver'; settings = [pscustomobject]@{ server = 'LABSERVER'; database = 'COMPULAB'; driver = 'Firebird' }; source = 'mock_local_odbc'; confidence = 'HIGH' })
        databaseDrivers = @([pscustomobject]@{ name = 'Firebird client library'; path = 'C:\Program Files\Firebird\fbclient.dll'; source = 'mock_local_client_library'; confidence = 'HIGH' })
        networkShares = @([pscustomobject]@{ localPath = 'Z:'; remotePath = '\\LABSERVER\COMPULAB'; source = 'mock_existing_smb_mapping'; confidence = 'CONFIRMED' })
        relatedServices = @()
        configurationHints = @([pscustomobject]@{ configFile = 'C:\Compulab\config.ini'; key = 'server'; value = 'LABSERVER'; source = 'mock_local_config'; confidence = 'HIGH' })
        architectureInference = $null
        warnings = @()
    }
}

function Get-LocalStaticData {
    param([AllowNull()][object]$Application, [AllowNull()][object]$Identification)
    $script:CollectionWarnings = @()
    function Invoke-LocalCollection {
        param([string]$Name, [scriptblock]$Action)
        try { return & $Action } catch { $script:CollectionWarnings += "$Name indisponível; a análise continuou."; return @() }
    }
    $system = Invoke-LocalCollection 'Informações do sistema' { Get-DiscoverySystemInfo }
    $odbc = Invoke-LocalCollection 'ODBC' { Get-DiscoveryOdbc }
    $drivers = Invoke-LocalCollection 'Drivers' { Get-DiscoveryDrivers }
    $shares = Invoke-LocalCollection 'Compartilhamentos locais' { Get-DiscoveryShares }
    $services = Invoke-LocalCollection 'Serviços locais' { Get-DiscoveryServices }
    $hints = if ($null -ne $Application -and (Test-IsLocalFixedPath $Application.path)) { Invoke-LocalCollection 'Configuração local' { Get-DiscoveryConfigHints $Application } } else { if ($null -ne $Application) { $script:CollectionWarnings += 'Configuração local ignorada: o executável não está em disco local fixo.' }; @() }
    return [ordered]@{
        system = $system; selectedApplication = $Application; applicationIdentification = ConvertTo-ReportableProcessIdentification $Identification
        network = [pscustomobject]@{ observation = 'TCP metadata only' }; observedConnections = @(); remoteEndpoints = @()
        odbc = @($odbc); databaseDrivers = @($drivers); networkShares = @($shares); relatedServices = @($services)
        configurationHints = @($hints); architectureInference = $null; warnings = @($script:CollectionWarnings)
    }
}

function Complete-DataInference {
    param([System.Collections.IDictionary]$Data)
    $Data.architectureInference = Get-ArchitectureInference -Endpoints @($Data.remoteEndpoints) -Drivers @($Data.databaseDrivers) -Hints @($Data.configurationHints)
    return $Data
}

if ($Headless) {
    if (-not $Mock) { throw 'O modo Headless do V0 aceita apenas dados simulados.' }
    $data = Get-MockData
    $data = Complete-DataInference $data
    $target = if ($ReportsRoot) { $ReportsRoot } else { Join-Path $root 'reports' }
    New-DiscoveryReport -Data $data -ReportsRoot $target
    return
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Hexxon Bridge Discovery" Height="660" Width="820" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" Background="#FAF9F7">
<Grid Margin="42"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<StackPanel><TextBlock Text="HEXXON" FontSize="26" FontWeight="Bold" Foreground="#35135C"/><TextBlock Text="Bridge Discovery" FontSize="18" Foreground="#5A4A6B"/><Border Height="1" Background="#DED6E8" Margin="0,14,0,16"/></StackPanel>
<Grid Grid.Row="1">
<StackPanel x:Name="WelcomePanel"><TextBlock Text="Vamos identificar automaticamente como o Compulab se conecta à infraestrutura do laboratório." FontSize="23" TextWrapping="Wrap"/><Border Background="White" Padding="22" Margin="0,25,0,0" CornerRadius="8"><StackPanel><TextBlock Text="✓ Somente leitura" Foreground="#167347" FontSize="16" Margin="0,4"/><TextBlock Text="✓ Nenhum dado enviado para serviços externos" Foreground="#167347" FontSize="16" Margin="0,4"/><TextBlock Text="✓ Nenhum sistema será alterado" Foreground="#167347" FontSize="16" Margin="0,4"/><TextBlock Text="✓ Nenhum dado clínico será coletado" Foreground="#167347" FontSize="16" Margin="0,4"/></StackPanel></Border></StackPanel>
<StackPanel x:Name="OpenPanel" Visibility="Collapsed"><TextBlock Text="1. Abra o Compulab" FontSize="24" FontWeight="SemiBold"/><TextBlock Text="Abra o Compulab normalmente e deixe-o funcionando. Não será necessário selecionar nenhum programa." FontSize="16" TextWrapping="Wrap" Margin="0,18,0,0"/><TextBlock Text="Quando estiver pronto, clique em Identificar automaticamente." FontSize="16" TextWrapping="Wrap" Margin="0,12,0,0"/></StackPanel>
<StackPanel x:Name="DetectPanel" Visibility="Collapsed"><TextBlock x:Name="DetectTitle" Text="2. Identificando o Compulab" FontSize="24" FontWeight="SemiBold"/><TextBlock x:Name="DetectStatus" Text="Analisando aplicações locais..." FontSize="17" TextWrapping="Wrap" Margin="0,22,0,0"/><ProgressBar x:Name="DetectProgress" IsIndeterminate="True" Height="12" Margin="0,24,0,0"/><TextBlock Text="A ferramenta usa somente nomes, caminhos e metadados técnicos locais. Nenhum processo será escolhido sem evidência suficiente." Foreground="#5A4A6B" TextWrapping="Wrap" Margin="0,20,0,0"/></StackPanel>
<StackPanel x:Name="ObservePanel" Visibility="Collapsed"><TextBlock Text="3. Use o Compulab por um minuto" FontSize="24" FontWeight="SemiBold"/><TextBlock x:Name="IdentifiedText" FontSize="15" Foreground="#167347" TextWrapping="Wrap" Margin="0,14,0,0"/><TextBlock Text="Enquanto observamos as conexões existentes, use o Compulab normalmente: consulte uma solicitação, exames ou um resultado." FontSize="16" TextWrapping="Wrap" Margin="0,16,0,0"/><TextBlock x:Name="TimerText" Text="Observando... 01:00" FontSize="24" Foreground="#35135C" Margin="0,25,0,14"/><TextBlock x:Name="ProcessStatus" Text="✓ Processo monitorado"/><TextBlock x:Name="ConnectionStatus" Text="• Nenhuma conexão observada até agora"/><TextBlock x:Name="StaticStatus" Text="• Analisando configuração técnica local"/></StackPanel>
<StackPanel x:Name="FinishPanel" Visibility="Collapsed"><TextBlock x:Name="FinishTitle" Text="Análise concluída" FontSize="25" FontWeight="SemiBold" Foreground="#167347"/><TextBlock x:Name="FinishSummary" FontSize="16" TextWrapping="Wrap" Margin="0,18,0,0"/><Border Background="White" Padding="16" Margin="0,20,0,0" CornerRadius="8"><TextBlock x:Name="ReportMessage" Foreground="#167347" TextWrapping="Wrap"/></Border><TextBlock Text="É seguro manter esta janela aberta. Ela só será fechada quando você clicar em Fechar ou no X." Foreground="#5A4A6B" Margin="0,16,0,0" TextWrapping="Wrap"/></StackPanel>
</Grid>
<DockPanel Grid.Row="2" Margin="0,22,0,0"><Button x:Name="HelpButton" Content="Preciso de ajuda" Width="150" DockPanel.Dock="Left"/><StackPanel Orientation="Horizontal" HorizontalAlignment="Right"><Button x:Name="PrimaryButton" Content="Começar" Width="230" Height="42" Background="#35135C" Foreground="White" FontSize="15"/><Button x:Name="SecondaryButton" Content="Finalizar agora" Width="170" Height="42" Margin="12,0,0,0" Visibility="Collapsed"/></StackPanel></DockPanel>
</Grid></Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$names = 'WelcomePanel','OpenPanel','DetectPanel','ObservePanel','FinishPanel','DetectTitle','DetectStatus','DetectProgress','IdentifiedText','TimerText','ProcessStatus','ConnectionStatus','StaticStatus','FinishTitle','FinishSummary','ReportMessage','PrimaryButton','SecondaryButton','HelpButton'
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) }

$script:State = 'welcome'; $script:BaselineProcessIds = @(Get-DiscoveryProcessIds); $script:Identification = $null
$script:MonitoredPids = @(); $script:Data = $null; $script:Connections = @(); $script:Seconds = $ObservationSeconds
$script:DetectionAttempts = 0; $script:DetectionTimer = $null; $script:ObservationTimer = $null; $script:Report = $null

function Stop-AllTimers {
    if ($script:DetectionTimer) { $script:DetectionTimer.Stop() }
    if ($script:ObservationTimer) { $script:ObservationTimer.Stop() }
}

function Set-UiState {
    param([string]$Name)
    foreach ($panel in @($WelcomePanel,$OpenPanel,$DetectPanel,$ObservePanel,$FinishPanel)) { $panel.Visibility = 'Collapsed' }
    $PrimaryButton.IsEnabled = $true; $SecondaryButton.IsEnabled = $true; $SecondaryButton.Visibility = 'Collapsed'
    switch ($Name) {
        'welcome' { $WelcomePanel.Visibility = 'Visible'; $PrimaryButton.Content = 'Começar' }
        'open' { $OpenPanel.Visibility = 'Visible'; $PrimaryButton.Content = 'Identificar automaticamente' }
        'detecting' { $DetectPanel.Visibility = 'Visible'; $DetectTitle.Text = '2. Identificando o Compulab'; $DetectProgress.Visibility = 'Visible'; $PrimaryButton.Content = 'Identificando...'; $PrimaryButton.IsEnabled = $false }
        'detection_failed' { $DetectPanel.Visibility = 'Visible'; $DetectTitle.Text = 'Não foi possível identificar com segurança'; $DetectProgress.Visibility = 'Collapsed'; $PrimaryButton.Content = 'Tentar novamente'; $SecondaryButton.Content = 'Gerar relatório parcial'; $SecondaryButton.Visibility = 'Visible' }
        'observing' { $ObservePanel.Visibility = 'Visible'; $PrimaryButton.Content = 'Observando...'; $PrimaryButton.IsEnabled = $false; $SecondaryButton.Content = 'Finalizar agora'; $SecondaryButton.Visibility = 'Visible' }
        'finalizing' { $FinishPanel.Visibility = 'Visible'; $FinishTitle.Text = 'Finalizando o relatório...'; $FinishTitle.Foreground = '#35135C'; $PrimaryButton.Content = 'Aguarde...'; $PrimaryButton.IsEnabled = $false }
        'reported' { $FinishPanel.Visibility = 'Visible'; $FinishTitle.Text = 'Análise concluída'; $FinishTitle.Foreground = '#167347'; $PrimaryButton.Content = 'Abrir pasta do relatório'; $SecondaryButton.Content = 'Fechar'; $SecondaryButton.Visibility = 'Visible' }
        'report_error' { $FinishPanel.Visibility = 'Visible'; $FinishTitle.Text = 'Não foi possível gerar o ZIP'; $FinishTitle.Foreground = '#B25B00'; $PrimaryButton.Content = 'Tentar gerar novamente'; $SecondaryButton.Content = 'Fechar'; $SecondaryButton.Visibility = 'Visible' }
    }
    $script:State = $Name
}

function Get-SummaryText {
    $inference = $script:Data.architectureInference
    $server = if ($inference.likelyServer) { '{0} ({1})' -f $inference.likelyServer.hostname, $inference.likelyServer.ip } else { 'Não identificado' }
    $technology = if (@($inference.possibleTechnologies).Count) { $inference.possibleTechnologies -join ', ' } else { 'Não identificada' }
    $app = if ($script:Data.selectedApplication) { $script:Data.selectedApplication.friendlyName } else { 'Não identificado — relatório parcial' }
    return "Aplicação: $app`nServidor provável: $server`nPossível tecnologia: $technology`nConexões observadas: $(@($script:Data.observedConnections).Count)`nODBC: $(@($script:Data.odbc).Count) | Compartilhamentos: $(@($script:Data.networkShares).Count) | Configurações relevantes: $(@($script:Data.configurationHints).Count)`nConfiança: $($inference.confidence)"
}

function Save-ReportAndShow {
    Set-UiState 'finalizing'
    $FinishSummary.Text = Get-SummaryText
    $ReportMessage.Text = 'Criando arquivos locais sanitizados...'
    try {
        $target = if ($ReportsRoot) { $ReportsRoot } else { Join-Path $root 'reports' }
        $script:Report = New-DiscoveryReport -Data $script:Data -ReportsRoot $target
        $ReportMessage.Text = "Relatório criado com sucesso:`n$($script:Report.zip)"
        Set-UiState 'reported'
    } catch {
        $ReportMessage.Text = 'Nada foi enviado ou alterado. Você pode tentar gerar o relatório novamente.'
        Set-UiState 'report_error'
    }
}

function Complete-Observation {
    try {
        if ($script:ObservationTimer) { $script:ObservationTimer.Stop() }
        $script:Data.observedConnections = @($script:Connections | Sort-Object pid, remoteAddress, remotePort, localAddress, localPort -Unique)
        if (-not $Mock) { $script:Data.remoteEndpoints = @(Get-RemoteEndpointMetadata -Connections @($script:Data.observedConnections)) }
        $script:Data = Complete-DataInference $script:Data
        Save-ReportAndShow
    } catch {
        if ($null -eq $script:Data) { Start-PartialReport; return }
        $script:Data.warnings += 'A finalização automática encontrou uma falha recuperável.'
        if ($null -eq $script:Data.architectureInference) { $script:Data.architectureInference = Get-ArchitectureInference -Endpoints @() -Drivers @($script:Data.databaseDrivers) -Hints @($script:Data.configurationHints) }
        Save-ReportAndShow
    }
}

function Start-Observation {
    param([object]$Identification)
    try {
        $script:Identification = $Identification
        $script:MonitoredPids = @($Identification.monitoredPids)
        $script:Connections = @(); $script:Seconds = $ObservationSeconds
        $application = $Identification.selected.application
        $script:Data = if ($Mock) { Get-MockData } else { Get-LocalStaticData -Application $application -Identification $Identification }
        $IdentifiedText.Text = "✓ Compulab identificado automaticamente: $($application.friendlyName) — PID $($application.pid)"
        $ProcessStatus.Text = "✓ Processo monitorado: $(@($script:MonitoredPids).Count) processo(s) relacionado(s)"
        $StaticStatus.Text = '✓ Configuração local, drivers, ODBC, rede e serviços analisados'
        $TimerText.Text = 'Observando... 00:{0:D2}' -f $script:Seconds
        Set-UiState 'observing'
        $script:ObservationTimer = New-Object Windows.Threading.DispatcherTimer
        $script:ObservationTimer.Interval = [TimeSpan]::FromSeconds(1)
        $script:ObservationTimer.Add_Tick({
            try {
                if ($Mock) {
                    $script:Connections = @($script:Data.observedConnections)
                } else {
                    foreach ($pidValue in @($script:MonitoredPids)) { $script:Connections += @(Get-ProcessConnections -ProcessId $pidValue) }
                    if (($script:Seconds % 10) -eq 0) {
                        $refresh = Find-CompulabProcess -BaselineProcessIds $script:BaselineProcessIds
                        if ($refresh.status -eq 'found') { $script:MonitoredPids = @($refresh.monitoredPids) }
                    }
                }
                $script:Seconds--
                $TimerText.Text = 'Observando... 00:{0:D2}' -f [Math]::Max(0, $script:Seconds)
                $connectionCount = @($script:Connections | Sort-Object pid, remoteAddress, remotePort -Unique).Count
                $ConnectionStatus.Text = if ($connectionCount) { "✓ Conexões observadas: $connectionCount" } else { '• Nenhuma conexão observada até agora — continue usando o Compulab' }
                if ($script:Seconds -le 0) { Complete-Observation }
            } catch {
                if ($null -ne $script:Data) { $script:Data.warnings += 'Uma amostra de conexão não pôde ser coletada; a observação continuou.' }
                $script:Seconds--
                if ($script:Seconds -le 0) { Complete-Observation }
            }
        })
        $script:ObservationTimer.Start()
    } catch {
        $DetectStatus.Text = 'O processo foi identificado, mas não foi possível iniciar a observação. Gere um relatório parcial ou tente novamente.'
        Set-UiState 'detection_failed'
    }
}

function Start-Identification {
    Stop-AllTimers
    $script:DetectionAttempts = 0
    $DetectStatus.Text = 'Analisando aplicações locais...'
    Set-UiState 'detecting'
    $script:DetectionTimer = New-Object Windows.Threading.DispatcherTimer
    $script:DetectionTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:DetectionTimer.Add_Tick({
        try {
            $script:DetectionAttempts++
            $result = if ($Mock) { Get-MockIdentification } else { Find-CompulabProcess -BaselineProcessIds $script:BaselineProcessIds }
            if ($result.status -eq 'found') {
                $script:DetectionTimer.Stop(); Start-Observation $result; return
            }
            $elapsed = $script:DetectionAttempts * 2
            $DetectStatus.Text = if ($result.status -eq 'ambiguous') { "Encontramos aplicações parecidas, mas ainda não há evidência suficiente. Continuaremos observando automaticamente. ($elapsed s)" } else { "Ainda não identificamos o Compulab. Deixe-o aberto; continuaremos tentando automaticamente. ($elapsed s)" }
            if ($script:DetectionAttempts -ge 15) {
                $script:DetectionTimer.Stop()
                $DetectStatus.Text = 'Não encontramos evidências suficientes para escolher um processo com segurança. Nenhuma aplicação aleatória foi analisada.'
                Set-UiState 'detection_failed'
            }
        } catch {
            $script:DetectionTimer.Stop()
            $DetectStatus.Text = 'A identificação encontrou uma falha recuperável. Nada foi alterado; tente novamente ou gere um relatório parcial.'
            Set-UiState 'detection_failed'
        }
    })
    $script:DetectionTimer.Start()
}

function Start-PartialReport {
    Stop-AllTimers
    try {
        $identity = [pscustomobject]@{ status = 'not_found'; selected = $null; ranked = @(); reason = 'Compulab não identificado automaticamente.'; monitoredPids = @(); source = 'automatic_local_process_identification' }
        $script:Data = if ($Mock) { Get-MockData } else { Get-LocalStaticData -Application $null -Identification $identity }
        if (-not $Mock) { $script:Data.selectedApplication = $null; $script:Data.observedConnections = @(); $script:Data.remoteEndpoints = @(); $script:Data.configurationHints = @(); $script:Data.warnings += 'Relatório parcial: Compulab não identificado automaticamente.' }
        $script:Data = Complete-DataInference $script:Data
        Save-ReportAndShow
    } catch {
        $FinishSummary.Text = 'Não foi possível concluir a coleta parcial.'
        $ReportMessage.Text = 'Nada foi alterado ou enviado. Feche a ferramenta e informe o responsável.'
        Set-UiState 'report_error'
    }
}

$PrimaryButton.Add_Click({
    try {
        switch ($script:State) {
            'welcome' { Set-UiState 'open' }
            'open' { Start-Identification }
            'detection_failed' { Start-Identification }
            'reported' { if ($script:Report) { Start-Process -FilePath explorer.exe -ArgumentList @($script:Report.directory) } }
            'report_error' { if ($null -ne $script:Data) { Save-ReportAndShow } else { Start-PartialReport } }
        }
    } catch { [System.Windows.MessageBox]::Show("Não conseguimos concluir esta ação.`nNada foi alterado. A janela permanecerá aberta.",'Hexxon Discovery','OK','Warning') | Out-Null }
})

$SecondaryButton.Add_Click({
    try {
        switch ($script:State) {
            'detection_failed' { Start-PartialReport }
            'observing' { Complete-Observation }
            'reported' { $window.Close() }
            'report_error' { $window.Close() }
        }
    } catch { [System.Windows.MessageBox]::Show('A ação não pôde ser concluída, mas a janela continuará aberta.','Hexxon Discovery','OK','Warning') | Out-Null }
})

$HelpButton.Add_Click({
    [System.Windows.MessageBox]::Show("1. Deixe o Compulab aberto.`n2. Clique em Tentar novamente se ele não for identificado.`n3. Se necessário, gere o relatório parcial.`n4. Envie o ZIP ao responsável.`n`nNão selecione processos nem altere o servidor.",'Preciso de ajuda','OK','Information') | Out-Null
})

$window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)
    try {
        Stop-AllTimers
        $eventArgs.Handled = $true
        [System.Windows.MessageBox]::Show("Encontramos uma falha inesperada, mas nada foi alterado.`nA janela continuará aberta e você poderá gerar um relatório parcial.",'Hexxon Discovery','OK','Warning') | Out-Null
        $DetectStatus.Text = 'Falha recuperável. Tente novamente ou gere um relatório parcial.'
        Set-UiState 'detection_failed'
    } catch { $eventArgs.Handled = $true }
})

$window.Add_Closed({ Stop-AllTimers })
Set-UiState 'welcome'
$window.ShowDialog() | Out-Null
