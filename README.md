# Hexxon Bridge — Discovery Agent V0

Ferramenta local, somente leitura, para mapear evidências técnicas de como uma aplicação clínica autorizada se comunica com a infraestrutura. Destina-se a Windows 10/11 ou Windows Server com desktop e Windows PowerShell 5.1. Não requer administrador, SDK, instalador nem acesso à internet.

## Uso

Abra o Compulab, extraia esta pasta e dê dois cliques em `INICIAR_DISCOVERY.bat`. O relatório sanitizado é criado em `reports/<data-hora>/` e compactado como `HexxonDiscoveryReport_<data-hora>.zip`. O envio do ZIP é sempre manual.

Para demonstração sem dados reais, execute `Start-MockDiscovery.ps1` no Windows PowerShell. O mock abre a mesma interface com evidências inteiramente fictícias.

## Arquitetura

`src/HexxonDiscovery.ps1` hospeda a GUI WPF e orquestra módulos independentes em `src/modules/`. Eles coletam informações do computador local, processo escolhido, metadados de conexões TCP existentes, ODBC local, drivers, compartilhamentos já montados, serviços locais e indícios restritos de configuração. `ArchitectureInference` correlaciona essas evidências; conclusões são sempre hipóteses, exceto fatos diretamente observados.

`ReportGenerator` cria `report.json` (schema 1.0), `report.html` offline, `summary.txt` e o ZIP. `PrivacySanitizer` remove campos secretos e limita conteúdo de configurações a pares técnicos permitidos.

## Modelo de segurança e privacidade

O código não autentica, consulta ou altera DBMS; não executa varredura, sondagem, remoting nem captura payloads. Não envia dados para rede ou internet. Não lê arquivos clínicos: a leitura de configuração é limitada aos diretórios diretamente associados ao executável escolhido, extensões específicas, 2 MB por arquivo e profundidade de dois níveis. Segredos e campos sensíveis são sempre redigidos.

Reveja `Test-Safety.ps1` antes de toda entrega. Ele procura APIs de rede externas e operações potencialmente mutáveis no código de produção. É uma barreira complementar a code review.

## Desenvolvimento e testes

No Windows PowerShell, execute `tests\Run-Tests.ps1`, depois `Test-Safety.ps1` e `Start-MockDiscovery.ps1`. Os testes usam apenas dados fictícios e verificam sanitização, parsing e geração de relatórios. Não execute o mock em uma entrega ao laboratório.

## Limitações

Sem privilégios elevados, alguns metadados podem não estar disponíveis. Reverse DNS usa somente a resolução padrão do Windows para endpoints já observados; não faz conexão ou scan. Portas indicam serviços possíveis, nunca confirmação por si sós.
