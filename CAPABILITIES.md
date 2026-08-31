# Capacidades do Hexxon Bridge Discovery V0

## O que o programa pode fazer

- Ler metadados do Windows e da versão do PowerShell.
- Ler metadados de processos locais para identificar o Compulab.
- Observar metadados de conexões TCP que já existem para o processo identificado.
- Ler configurações ODBC locais, drivers instalados, serviços locais e compartilhamentos já montados.
- Ler somente chaves técnicas permitidas em arquivos de configuração pequenos, localizados em disco fixo local e associados ao executável identificado.
- Criar relatório sanitizado exclusivamente em disco fixo local.
- Compactar o relatório local em ZIP.
- Abrir a pasta local do relatório quando o usuário solicitar.

## O que o programa não pode fazer

- Conectar, autenticar ou executar comandos em banco de dados.
- Capturar payload, conteúdo TCP ou dados clínicos.
- Fazer scan, ping sweep, socket probing ou tentativa de login.
- Executar remoting, alterar serviços, processos, firewall, Registro, ODBC, DNS ou adaptadores.
- Ler configuração por UNC ou unidade de rede mapeada.
- Escrever relatório em UNC ou unidade de rede mapeada.
- Resolver DNS reverso de endpoints.
- Fazer upload, telemetria, analytics, webhook ou chamada HTTP.
- Selecionar uma aplicação somente porque foi aberta recentemente; uma evidência forte de Compulab ou Performática é obrigatória.

## Dados deliberadamente descartados

O título original de qualquer janela é usado apenas transitoriamente para gerar indicadores booleanos de correspondência. O texto integral não é preservado em memória de relatório, logs, JSON, HTML ou ZIP. A lista completa de processos candidatos também não é incluída no relatório.
