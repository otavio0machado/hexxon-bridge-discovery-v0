# Hexxon Bridge — Discovery Agent V0.3

Ferramenta local, somente leitura, para mapear evidências técnicas de como uma aplicação clínica autorizada se comunica com a infraestrutura. Destina-se a Windows 10/11 ou Windows Server com desktop e Windows PowerShell 5.1. Não requer administrador, SDK, instalador nem acesso à internet.

## Uso

Extraia esta pasta e dê dois cliques em `INICIAR_DISCOVERY.bat`. A interface orienta o usuário a abrir o Compulab e faz a identificação automaticamente; não existe seleção manual de processos. O relatório sanitizado é criado e compactado automaticamente como `HexxonDiscoveryReport_<data-hora>.zip`. O envio do ZIP é sempre manual.

Para demonstração sem dados reais, execute `Start-MockDiscovery.ps1` no Windows PowerShell. O mock abre a mesma interface com evidências inteiramente fictícias.

## Arquitetura

`src/HexxonDiscovery.ps1` hospeda a GUI WPF e uma máquina de estados tolerante a falhas. `ProcessDiscovery` identifica o Compulab por uma combinação de nome, caminho, metadados de versão, fabricante, produto, título da janela, assinatura digital, produto instalado e processo iniciado após a orientação. Um candidato só é aceito quando atinge o limite mínimo e não há ambiguidade. O processo principal e seus descendentes são observados.

Os demais módulos coletam informações do computador local, metadados de conexões TCP existentes, ODBC local, drivers, compartilhamentos já montados, serviços locais e indícios restritos de configuração. `ArchitectureInference` correlaciona essas evidências; conclusões são sempre hipóteses, exceto fatos diretamente observados.

`ReportGenerator` cria `report.json` (schema 1.2), `report.html` offline, `summary.txt` e o ZIP. O relatório registra apenas as evidências mínimas da identificação automática ou informa claramente que é parcial. `PrivacySanitizer` remove campos secretos, mascara diretórios do perfil do usuário e limita conteúdo de configurações a pares técnicos permitidos.

## Modelo de segurança e privacidade

O código não autentica, consulta ou altera DBMS; não executa varredura, resolução DNS, sondagem, remoting nem captura payloads. Não envia dados para rede ou internet. Não lê arquivos clínicos: a leitura de configuração é limitada a disco fixo local, aos diretórios diretamente associados ao executável identificado, extensões específicas, 2 MB por arquivo e profundidade de dois níveis. Segredos e campos sensíveis são sempre redigidos. Relatórios também são recusados em UNC, unidades mapeadas e pontos de redirecionamento.

O launcher executa `Test-Safety.ps1` antes de abrir a interface. O gate inspeciona os arquivos executáveis do pacote, o launcher e invariantes de privacidade e caminhos locais. GitHub Actions repete parser, gate e testes no Windows PowerShell 5.1 em cada push e pull request.

## Desenvolvimento e testes

No Windows PowerShell, execute `tests\Run-Tests.ps1`, depois `Test-Safety.ps1` e `Start-MockDiscovery.ps1`. Os testes usam apenas dados fictícios e verificam sanitização, parsing, identificação automática, rejeição de falsos positivos, árvore de processos, relatório parcial e execução headless completa. Não execute o mock em uma entrega ao laboratório.

O roteiro completo de homologação está em `TESTE-NO-WINDOWS.md`.

## Limitações

Sem privilégios elevados, alguns metadados podem não estar disponíveis. Quando a evidência forte é insuficiente ou ambígua, a ferramenta não escolhe um processo; oferece nova tentativa ou relatório parcial. O V0 não executa reverse DNS. Portas indicam serviços possíveis, nunca confirmação por si sós. Consulte `CAPABILITIES.md` e `SAFETY_MANIFEST.md` antes de uma release.
