# CCMA Project Template v2.2.0

Vorlage für neue Projekte mit dem CCMA Multi-Agent Framework.

## Schnellstart

```bash
# 1. Template kopieren
cp -r ccma-template/ mein-projekt/
cd mein-projekt/

# 2. CLAUDE.md ausfüllen
#    - Projektname, Build/Test/Lint Commands
#    - Architektur-Übersicht
#    - Conventions und Known Pitfalls
#    - Security-Sensitive Paths

# 3. Projekt-Code anlegen
mkdir -p src tests

# 4. Verify
bash .ccma/scripts/ccma-verify.sh

# 5. Git init
git init && git add -A && git commit -m "Initial commit with CCMA"

# 6. Claude Code starten
claude
```

## Struktur

```
.ccma/                          Framework (versteckt)
├── scripts/                    14 Hook- und Utility-Scripts
│   └── ccma-commit.sh          Optionaler Auto-Commit nach Pipeline-SUCCESS
├── tests/                      5 bats Framework-Tests
├── scratchpad.md               Pipeline-State (automatisch)
├── scratchpad-template.md      Reset-Vorlage
├── MEMORY.md                   Cross-Task-Wissen
└── disruption-proposals.md     Config-Änderungsvorschläge

.claude/                        Claude Code native (versteckt)
├── agents/                     6 Agent-Definitionen
├── skills/                     Task-Checklisten
├── settings.json               Hooks + Permissions
├── delegation-rules.md         Pipeline-Regeln
├── pipeline-log.jsonl          Task-Verlauf
├── activity-log.jsonl          Tool-Call-Protokoll
└── disruption-log.jsonl        Guard-Blocks

CLAUDE.md                       ← DAS HIER AUSFÜLLEN
```

## Pipeline-Klassen

| Klasse | Agents | Wann |
|--------|--------|------|
| MICRO | Orchestrator direkt | Typo, Kommentar, ≤5 Zeilen |
| TRIVIAL | coder → tester | 1 Funktion, 1 Datei |
| STANDARD | planner → coder → tester → reviewer | Feature, Modul, Refactoring |
| COMPLEX | planner → coder → tester → reviewer → security-auditor | Auth, Crypto, API-Keys — inkl. Security Pre-Check des Plans vor coder |

## Slash Commands

| Command | Aktion |
|---------|--------|
| `/implement "..."` | Starte Pipeline für Task |
| `/status` | Zeige Scratchpad + Logs |
| `/retro` | Starte Retrospective |
| `/retro --force` | Erzwinge Retrospective |

### Konfiguration (ccma-config.sh)

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `CCMA_AUTO_COMMIT` | `false` | Automatischer git commit nach SUCCESS |
| `CCMA_MEMORY_MAX_LINES` | `150` | MEMORY.md wird bei Überschreitung getrimmt |
| `CCMA_CODER_MAX_TURNS_*` | 15/40/60/80 | maxTurns pro Task-Klasse (TRIVIAL/STANDARD/COMPLEX/ARCH) |

## Wichtig

- **CLAUDE.md komplett ausfüllen** — die Agents lesen das als erste Quelle
- **Keine `bash`-Prefixe** bei Script-Aufrufen **aus Agent Tool Calls heraus** — der Bash Guard blockt es. Im Terminal (Quickstart Schritt 4) ist `bash script.sh` weiterhin korrekt.
- **`process-adaptations.md`** nach jeder Retro prüfen und Vorschläge manuell umsetzen
- **Windows:** `defaultMode: acceptEdits` ist gesetzt, Permission-Prompts sollten nicht auftreten
- **Orchestrator-Guard ist Observability, kein Enforcement** — hohe `orchestrator-guard`-Einträge in `.claude/disruption-log.jsonl` signalisieren dass der Orchestrator direkt Code geschrieben hat statt zu delegieren. Das ist ein Prozessfehler, kein Security-Incident.
- **Datei-Löschungen**: Agents können Dateien nicht löschen (`rm` ist aus der Bash-Whitelist ausgeschlossen, Write/Edit decken nur Erstellung/Änderung ab). Workflow: Coder gibt `PARTIAL` zurück mit explizitem Hinweis auf zu löschende Dateien → Human löscht manuell → Coder-Invoke mit `mode: continue`.
