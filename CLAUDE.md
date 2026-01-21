# La Forge - Command Center

## 🎯 Purpose

**La Forge** est le hub d'orchestration pour tous les projets de Thomas.

Tu es dans La Forge quand tu dois :
- Créer un nouveau projet
- Raffiner des requirements
- Revoir l'architecture cross-projets
- Accéder aux templates et patterns

## 📍 Tu es ICI : La Forge

Ce n'est PAS un projet de code. C'est le **command center**.

### Ce qu'on fait ici :
- `/forge-orchestrator:new-project` - Créer un nouveau projet
- `/forge-orchestrator:project-status` - Voir le status des projets
- Raffiner des besoins avant de coder
- Consulter les templates et patterns

### Ce qu'on ne fait PAS ici :
- Coder des features
- Débugger du code
- Faire des commits

Pour coder, va dans le projet concerné : `cd ~/[nom-projet] && claude`

---

## 📁 Structure de La Forge

```
la-forge/
├── CLAUDE.md                    ← Tu es ici
├── .claude-plugin/
│   └── marketplace.json         # Définit le marketplace "la-forge"
├── plugins/
│   └── forge-orchestrator/      # Plugin d'orchestration
│       ├── commands/            # /new-project, /project-status
│       └── skills/              # requirements-engineer
├── templates/                   # Templates par type de projet
│   ├── webapp-nextjs/
│   ├── api-fastapi/
│   ├── data-pipeline-aws/
│   ├── mobile-ios/
│   ├── mobile-android/
│   └── infrastructure-terraform/
└── knowledge/                   # Base de connaissances
    ├── patterns/                # Patterns architecturaux
    ├── decisions/               # ADRs globaux
    └── learnings/               # Retours d'expérience
```

---

## 🔄 Workflow Principal : Nouveau Projet

### Étape 1 : Lancer la création
```
/forge-orchestrator:new-project
```

### Étape 2 : Répondre aux questions de raffinement
Le skill `requirements-engineer` va poser des questions pour comprendre :
- Le contexte métier
- Les utilisateurs
- Le problème à résoudre
- Les contraintes

### Étape 3 : Valider l'architecture
Une fois le besoin compris, validation de :
- Type de projet (webapp, api, data, mobile, infra)
- Stack technique
- Structure proposée

### Étape 4 : Génération
La Forge crée :
- Le dossier `~/[nom-projet]/`
- Le CLAUDE.md avec tout le contexte
- La structure de base
- La config pour hériter des guidelines

### Étape 5 : Handoff
```bash
cd ~/[nom-projet]
claude
# L'agent du projet est maintenant autonome
```

---

## 📚 Templates Disponibles

| Type | Description | Stack |
|------|-------------|-------|
| `webapp-nextjs` | Application web | Next.js 15, TypeScript, Tailwind |
| `api-fastapi` | API backend | FastAPI, Python, PostgreSQL |
| `data-pipeline-aws` | Pipeline données | AWS Glue/Lambda, S3, Terraform |
| `mobile-ios` | App iOS | Swift ou React Native |
| `mobile-android` | App Android | Kotlin ou React Native |
| `infrastructure-terraform` | IaC pure | Terraform, AWS |

---

## 🔗 Héritage des Guidelines

Les projets créés par La Forge héritent automatiquement de :

### Via `~/.claude/` (automatique)
- `CLAUDE.md` - Guidelines globales (sécurité, conventions)
- `commands/` - Commands génériques (refactor, debug, test, review)
- `skills/` - Skills génériques (aws-expert, code-reviewer)
- `settings.json` - Hooks de sécurité

### Via le marketplace `la-forge` (opt-in)
- Plugin `forge-orchestrator` pour orchestration
- Templates de projet
- Patterns et ADRs

---

## ⚠️ Règles dans La Forge

1. **Pas de code ici** - La Forge ne contient pas de code projet
2. **Raffiner avant de créer** - Ne jamais créer un projet sans comprendre le besoin
3. **Valider avec l'utilisateur** - Confirmer le type et l'architecture avant génération
4. **Documenter le contexte** - Le CLAUDE.md du projet doit être auto-suffisant

---

## 🚀 Quick Start

### Créer un projet
```
/forge-orchestrator:new-project SportCoach marketplace de coachs
```

### Voir les projets existants
```
/forge-orchestrator:project-status
```

### Consulter un template
```
Montre-moi le template webapp-nextjs
```

### Ajouter un pattern
```
Ajoute ce pattern dans knowledge/patterns/
```
