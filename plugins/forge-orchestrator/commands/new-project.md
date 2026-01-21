---
description: Create a new project with full context and structure
allowed-tools: Read, Write, Bash, Glob, WebFetch
---

# Création de Nouveau Projet

## Contexte
Tu es dans La Forge, le command center. L'utilisateur veut créer un nouveau projet.

## Processus

### Phase 1 : Comprendre le Besoin (OBLIGATOIRE)

Pose ces questions dans l'ordre :

**Contexte Métier :**
1. C'est pour quel client/projet ? (juste un nom, pas de détails confidentiels)
2. En une phrase, c'est quoi ce projet ?
3. Qui sont les utilisateurs finaux ? (pas combien, mais qui)
4. Quel problème principal résolvent-ils ?
5. Qu'est-ce qui fait que ce projet est un succès ?

**Contraintes :**
6. Y a-t-il des contraintes techniques imposées ? (stack, hébergement, existant)
7. Budget/deadline particuliers à noter ?
8. Intégrations requises ? (paiement, auth externe, API tierces)

**Attends les réponses avant de continuer.**

### Phase 2 : Définir le Type de Projet

Basé sur les réponses, identifie le type :
- `webapp-nextjs` - Application web Next.js
- `api-fastapi` - API backend Python FastAPI
- `data-pipeline-aws` - Pipeline de données AWS
- `mobile-ios` - Application iOS (Swift ou React Native)
- `mobile-android` - Application Android (Kotlin ou React Native)
- `infrastructure-terraform` - Infrastructure pure Terraform/CDK
- `custom` - Autre (définir la structure)

Confirme avec l'utilisateur.

### Phase 3 : Proposer l'Architecture

Propose une architecture high-level :
- Stack technique
- Services principaux
- Structure de dossiers

**Attends validation avant de créer.**

### Phase 4 : Créer le Projet (avec Isolation)

1. **Enregistre le projet dans La Forge** :
   ```bash
   # Obtenir un ID unique pour l'isolation
   PROJECT_ID=$(~/la-forge/core/isolation/isolation-utils.sh register "[nom-projet]" "[type]" "[client]")
   ```

2. **Crée le dossier** : `~/[nom-projet]/`

3. **Configure l'isolation** :
   ```bash
   # Générer le fichier de ports
   ~/la-forge/core/isolation/isolation-utils.sh generate-env "[nom-projet]" ~/[nom-projet]/.env.ports

   # Copier le docker-compose de base
   cp ~/la-forge/core/isolation/docker-compose.base.yml ~/[nom-projet]/docker-compose.yml
   ```

4. **Copie le template** approprié depuis `~/la-forge/templates/[type]/`

5. **Génère le CLAUDE.md** avec :
   - Tout le contexte métier raffiné
   - L'architecture décidée
   - **L'identifiant projet (PROJECT_ID) pour l'isolation**
   - **Le nom client pour le tagging AWS**
   - Les commandes de dev
   - La référence au marketplace la-forge

6. **Configure l'environnement isolé** :
   - `.env.example` - Variables incluant les ports du projet
   - `.env.ports` - Ports assignés (généré automatiquement)
   - `docker-compose.yml` - Services avec ports isolés
   - `.gitignore` - Inclure `.env*` (sauf `.env.example`)

7. **Configure .claude/settings.json** avec référence à la-forge

8. **Initialise git** : `git init`

9. **Initialise Forge (multi-agent)** :
   ```bash
   # Initialiser la structure .forge/ pour le développement multi-agents
   ~/la-forge/core/scripts/forge-init.sh ~/[nom-projet]
   ```
   Cela crée:
   - `.forge/backlog/tickets.json` - Backlog du projet
   - `.forge/agent-state/` - Communication inter-agents
   - `.forge/progress.json` - Suivi du progrès
   - `.claude/agents/` - Agents copiés depuis La Forge
   - Hooks configurés dans `.claude/settings.json`

10. **Configure les dépendances isolées** :
   - Python : `python -m venv .venv` dans le projet
   - Node.js : `node_modules/` local (défaut npm)
   - Tout reste dans le dossier projet

### Phase 5 : Handoff

Affiche un résumé :
```
✅ Projet créé : ~/[nom-projet]/

🔒 Isolation :
   Project ID: [XX]
   Client: [client-name]

🌐 Ports assignés :
   Web:      30XX
   API:      50XX
   Postgres: 54XX
   Redis:    63XX

📁 Structure :
[arborescence]

🚀 Pour commencer :
cd ~/[nom-projet]
docker compose up -d                           # Démarrer les services
claude                                         # Lancer un agent unique
# OU
~/la-forge/core/scripts/forge-team.sh .        # Lancer l'équipe multi-agents

🤖 Équipe Multi-Agents :
   Supervisor:     Coordonne et assigne les tickets
   Developer:      Implémente le code
   Code-reviewer:  Review la qualité
   QA-tester:      Teste les implémentations

📊 Dashboard :
   ~/la-forge/core/scripts/forge-dashboard.sh . --watch

📝 Le CLAUDE.md contient tout le contexte.
   L'agent sera autonome et héritera des guidelines de La Forge.

⚠️ Rappels Isolation :
   - Dépendances : utiliser .venv (Python) ou node_modules local
   - AWS : TOUS les tags doivent inclure Project=[nom-projet]
   - DB partagée : utiliser le schema/database dédié
```

## Arguments
$ARGUMENTS - Nom ou description initiale du projet (optionnel)

## Important
- NE PAS créer sans avoir raffiné le besoin
- NE PAS supposer des choix techniques sans validation
- TOUJOURS inclure le contexte métier dans CLAUDE.md
- TOUJOURS référencer la-forge dans settings.json du nouveau projet
