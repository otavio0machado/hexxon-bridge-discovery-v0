# Safety Manifest — Hexxon Bridge Discovery V0.3

Este manifesto descreve as propriedades de segurança verificadas pelo projeto. Ele complementa revisão humana; não é uma prova formal de ausência de defeitos.

## Invariantes obrigatórios

1. A identidade do Compulab exige pelo menos uma evidência forte: nome/caminho/produto contendo Compulab, fabricante Performática, assinatura correspondente, título correspondente reduzido imediatamente a booleano ou diretório de instalação confirmado.
2. Contexto temporal, PID novo ou janela visível nunca são suficientes isoladamente.
3. Títulos de janelas e a lista de candidatos não podem aparecer no relatório.
4. Leitura de configurações e escrita de relatórios são permitidas somente em disco fixo local.
5. O agente não inicia resolução DNS, HTTP, sockets, autenticação, DBMS, remoting ou varredura.
6. O launcher executa `Test-Safety.ps1` antes de abrir a GUI. Falha no gate impede a inicialização.
7. Falha de um módulo não autoriza expansão de coleta nem operação ativa.

## Gates

- `Test-Safety.ps1` inspeciona os arquivos executáveis do pacote e aplica regras estritas ao código de produção e ao launcher.
- `tests/Run-Tests.ps1` verifica sanitização, parsing, identidade forte, rejeição de falso positivo, ambiguidade, caminhos remotos, relatório parcial e mock headless.
- `.github/workflows/safety.yml` executa parser, safety gate e testes no Windows PowerShell 5.1 em cada push e pull request.
- `.github/workflows/release.yml` só publica uma tag após os testes e inclui checksum SHA-256 do ZIP.

## Limitações e operação

- Uma versão obtida diretamente da branch não possui a mesma garantia de empacotamento de uma release validada.
- O operador deve preferir o ZIP de uma GitHub Release e conferir `SHA256SUMS.txt`.
- Branch protection e exigência de status checks devem ser habilitadas nas configurações do GitHub pelo proprietário do repositório.
- A primeira execução real deve ocorrer em Windows Sandbox ou estação de homologação antes do laboratório clínico.
