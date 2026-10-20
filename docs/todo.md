# TODO

## HiPrio

- 'win-app-spy' skill
- Migrace 'win-app-spy' skillu do MCP
- Převést logiku pomocných testovacích skriptů do ts?
- AGENTS-SHARED.md:
  - Vyjmout kapitolu "Code changes" do vlastního reference dokumentu?

## LoPrio

- 'browser-app-spy' skill
- Sladit skilly s pravidly 'skill-authoring' (#42):
  - 'win-app-spy' — přejmenovat `preflight` na `check-prerequisites`, zrušit session state skriptu,
    výsledek jako jeden řádek `::result::`, popis odpovědí a chybových kódů přesunout do helpu
    skriptu, všechny skripty v jednom jazyce
  - 'notify' — help skriptu podle osnovy (`.NOTES` s exit kódy a stderr), exit kódy (očekávané
    chyby od 2, ne 1), skill pojmenuje příkaz, který help vypíše
  - `implicit-skills.yaml` — důvod "Tool skill" u 'win-app-spy': tool skill je teď workflow skill
