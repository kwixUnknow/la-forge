# La Forge - Autonomous Multi-Agent Development System

Hub d'orchestration pour les projets de Thomas Dev Agency, avec support pour équipes d'agents IA autonomes.

## Features

- **Création de projets** avec isolation complète (ports, IDs, containers)
- **Équipe multi-agents** autonome (supervisor, developer, reviewer, tester)
- **Backlog automatisé** avec transitions de status
- **Dashboard temps réel** pour suivre le progrès
- **Templates** pour 6 types de projets

## Quick Start

### Créer un nouveau projet

```bash
cd ~/la-forge
claude
# Dans Claude: /forge-orchestrator:new-project MonProjet
```

### Lancer l'équipe multi-agents

```bash
cd ~/mon-projet
~/la-forge/core/scripts/forge-team.sh .
```

### Voir le dashboard

```bash
~/la-forge/core/scripts/forge-dashboard.sh ~/mon-projet --watch
```

## Architecture

```
la-forge/
├── core/
│   ├── agents/           # Définitions des agents (supervisor, developer, etc.)
│   ├── backlog/          # Schema et templates pour le backlog
│   ├── isolation/        # Système d'isolation des projets
│   └── scripts/          # Scripts d'orchestration
├── plugins/
│   └── forge-orchestrator/  # Commands: new-project, team, backlog
├── templates/            # Templates par type de projet
└── knowledge/            # Patterns, ADRs, learnings
```

## Équipe d'Agents

| Agent | Modèle | Rôle |
|-------|--------|------|
| **supervisor** | Opus | Coordonne l'équipe, assigne les tickets |
| **developer** | Sonnet | Implémente les features, écrit les tests |
| **code-reviewer** | Sonnet | Review le code, approuve/rejette |
| **qa-tester** | Haiku | Teste, crée des bug tickets si échec |
| **planner** | Sonnet | Décompose les epics en tickets |

## Workflow Automatisé

```
┌──────────┐    ┌──────┐    ┌─────────────┐    ┌────────┐    ┌─────────┐    ┌──────┐
│ backlog  │ -> │ todo │ -> │ in_progress │ -> │ review │ -> │ testing │ -> │ done │
└──────────┘    └──────┘    └─────────────┘    └────────┘    └─────────┘    └──────┘
                    │              │                │              │
               [supervisor]   [developer]    [code-reviewer]  [qa-tester]
```

Les transitions sont automatiques grâce aux hooks Claude Code.

## Commandes

| Commande | Description |
|----------|-------------|
| `/forge-orchestrator:new-project` | Crée un nouveau projet avec isolation |
| `/forge-orchestrator:project-status` | Voir le status de tous les projets |
| `/forge-orchestrator:team` | Lance l'équipe multi-agents (tmux) |
| `/forge-orchestrator:backlog` | Gère le backlog du projet |

## Scripts

| Script | Description |
|--------|-------------|
| `forge-init.sh` | Initialise .forge/ dans un projet existant |
| `forge-team.sh` | Lance 4 agents dans tmux |
| `forge-dashboard.sh` | Dashboard CLI temps réel |
| `forge-watcher.sh` | Watch les handoffs et notifie |

## Structure d'un Projet Forgé

```
mon-projet/
├── .forge/
│   ├── backlog/
│   │   ├── tickets.json    # Tickets du projet
│   │   └── schema.json     # Validation
│   ├── agent-state/
│   │   ├── supervisor/     # inbox.json, outbox.json
│   │   ├── developer/
│   │   ├── code-reviewer/
│   │   └── qa-tester/
│   ├── reviews/            # Code reviews
│   ├── decisions/          # ADRs
│   ├── progress.json       # État actuel
│   └── metrics.json        # Métriques
├── .claude/
│   ├── agents/             # Agents copiés
│   └── settings.json       # Hooks configurés
└── CLAUDE.md               # Contexte projet
```

## Configuration

### Référencer La Forge dans un projet

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "la-forge": {
      "source": {
        "source": "path",
        "path": "~/la-forge"
      }
    }
  }
}
```

### Hooks auto-configurés

Les hooks sont configurés automatiquement par `forge-init.sh`:
- `SessionStart`: Charge le contexte de l'agent
- `PostToolUse`: Détecte les transitions de tickets
- `Stop`: Gère le handoff à l'agent suivant

## Pré-requis

- **Claude Code** installé
- **tmux** pour le multi-terminal: `brew install tmux`
- **jq** pour le JSON: `brew install jq`
- **fswatch** (optionnel) pour le watcher: `brew install fswatch`

## Usage Avancé

### Lancer un agent individuellement

```bash
cd ~/mon-projet
FORGE_AGENT_ROLE=developer claude
```

### Ajouter un ticket manuellement

```bash
# Éditer .forge/backlog/tickets.json
jq '.tickets += [{
  "id": "TICKET-001",
  "type": "feature",
  "title": "Implement login",
  "status": "todo",
  "priority": "high",
  "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}] | .next_id = 2' .forge/backlog/tickets.json > tmp.json && mv tmp.json .forge/backlog/tickets.json
```

### Voir l'activité récente

```bash
jq '.recent_activity[:5]' .forge/progress.json
```

## Templates Disponibles

| Type | Stack | Description |
|------|-------|-------------|
| `webapp-nextjs` | Next.js 15, TypeScript, Tailwind | Application web |
| `api-fastapi` | FastAPI, Python, PostgreSQL | API backend |
| `data-pipeline-aws` | Glue, Lambda, S3, Terraform | Pipeline données |
| `mobile-ios` | Swift / React Native | App iOS |
| `mobile-android` | Kotlin / React Native | App Android |
| `infrastructure-terraform` | Terraform, AWS | IaC pure |

## Isolation des Projets

Chaque projet reçoit:
- **ID unique** (01-99)
- **Ports dédiés**: Web=30XX, API=50XX, DB=54XX, Redis=63XX
- **Tags AWS**: Project, Environment, Owner, CostCenter
- **Containers nommés**: `{projet}-{service}`

Voir `core/isolation/` pour les détails.
