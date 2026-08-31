# Roteiro de validação no Windows

## 1. Testes automatizados

Abra o Windows PowerShell na pasta do projeto e execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Safety.ps1
```

Ambos devem terminar com mensagem verde de sucesso.

## 2. Mock da interface

Execute `Start-MockDiscovery.ps1`. O fluxo deve:

1. não mostrar lista de processos;
2. identificar automaticamente o Compulab simulado;
3. observar por 10 segundos;
4. gerar o ZIP automaticamente;
5. permanecer aberto na tela final até clicar em **Fechar**.

## 3. Computador sem Compulab

Execute `INICIAR_DISCOVERY.bat`, não abra o Compulab e solicite a identificação. Após aproximadamente 30 segundos, a ferramenta deve informar que não conseguiu identificar com segurança. Ela não deve escolher outro programa. Teste **Tentar novamente** e **Gerar relatório parcial**.

## 4. Computador com Compulab

Abra a ferramenta, siga a orientação para abrir o Compulab e clique em **Identificar automaticamente**. Confirme no relatório que `applicationIdentification.status` é `found`, que as evidências correspondem ao produto e que o processo identificado é realmente o Compulab.
