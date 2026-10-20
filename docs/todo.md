# TODO

## HiPrio

- AGENTS-SHARED.md: Vyjmout kapitolu "Code changes" do vlastního reference dokumentu?
- Použít 'Chat Customizations Evaluations - Analyze' nad veškerým agent context (skilly, atd.)
- Pustit veškeré evaly (ale postupně, ať nepripalim vsechny tokeny)

## MidPrio

- Sloučit ai-tools-common a ai-tools-custom:
  - Název repa: agentic-toolkit
  - Budou sdílet docs a CI
  - Root repa bude mít adresáře: 1. specific (současné cuatom); 2. general (současné common)
  - poté Summarní commit a verze package 1.0.0
- Migrace 'win-app-spy' skillu do MCP (viz devnotes): MCP bude součástí repa 'agentic-toolkit-mcps'?

## LoPrio

- Vytvořit 'browser-app-spy' skill (viz devnotes)
- Převést logiku pomocných testovacích skriptů do ts?
