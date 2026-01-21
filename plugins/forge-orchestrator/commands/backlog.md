# /forge-orchestrator:backlog - Gestion du backlog

Affiche et gère le backlog du projet.

## Usage

```
/forge-orchestrator:backlog [action] [args]
```

## Actions

### Lister les tickets
```
/forge-orchestrator:backlog list
/forge-orchestrator:backlog list --status todo
/forge-orchestrator:backlog list --assignee developer
```

### Voir un ticket
```
/forge-orchestrator:backlog show TICKET-001
```

### Créer un ticket
```
/forge-orchestrator:backlog create "Titre du ticket" --type feature --priority high
```

### Changer le status
```
/forge-orchestrator:backlog move TICKET-001 review
```

### Assigner
```
/forge-orchestrator:backlog assign TICKET-001 developer
```

## Comportement

### Action: list

Afficher les tickets sous forme de tableau:

```
ID          Type     Status       Priority  Title
----------- -------- ------------ --------- ----------------------------------
TICKET-001  feature  in_progress  high      Implement user authentication
TICKET-002  task     todo         medium    Add password validation
BUG-001     bug      todo         critical  Fix login redirect loop
```

Filtres disponibles:
- `--status [backlog|todo|in_progress|review|testing|done|blocked]`
- `--type [feature|task|bug|spike|chore|docs]`
- `--assignee [supervisor|developer|code-reviewer|qa-tester|planner]`
- `--priority [critical|high|medium|low]`

### Action: show

Afficher les détails complets d'un ticket:

```markdown
# TICKET-001: Implement user authentication

**Type**: feature
**Status**: in_progress
**Priority**: high
**Assignee**: developer
**Complexity**: L

## Description
Add JWT-based authentication with email/password login.

## Acceptance Criteria
- [ ] User can register with email and password
- [ ] User can login and receive JWT
- [ ] Protected routes require valid JWT

## History
- 2026-01-21 10:00 - Created (supervisor)
- 2026-01-21 12:00 - backlog → todo (supervisor)
- 2026-01-21 14:00 - todo → in_progress (developer)
```

### Action: create

Créer un nouveau ticket interactivement ou via arguments:

```bash
# Interactif
/forge-orchestrator:backlog create

# Avec arguments
/forge-orchestrator:backlog create "Titre" --type feature --priority high --description "Description détaillée"
```

Champs requis:
- `title`: Titre du ticket
- `type`: feature|task|bug|spike|chore|docs
- `priority`: critical|high|medium|low (défaut: medium)

Champs optionnels:
- `--description`: Description détaillée
- `--ac`: Acceptance criteria (peut être répété)
- `--parent`: Ticket parent
- `--labels`: Labels séparés par virgule
- `--complexity`: XS|S|M|L|XL

### Action: move

Changer le status d'un ticket:

```bash
/forge-orchestrator:backlog move TICKET-001 review
```

Transitions valides:
```
backlog     → todo
todo        → in_progress
in_progress → review | blocked
review      → testing | in_progress (rejection)
testing     → done | in_progress (bug found)
blocked     → in_progress
any         → rejected
```

### Action: assign

Assigner un ticket à un agent:

```bash
/forge-orchestrator:backlog assign TICKET-001 developer
```

L'assignation:
1. Met à jour `assignee` dans le ticket
2. Ajoute une tâche dans l'inbox de l'agent
3. Met à jour progress.json

## Implémentation

Cette commande doit:

1. Lire `.forge/backlog/tickets.json`
2. Appliquer l'action demandée
3. Mettre à jour le fichier si modification
4. Afficher le résultat

Exemple de code pour lister:
```bash
jq '.tickets[] | {id, type, status, priority, title}' .forge/backlog/tickets.json
```

Exemple de code pour créer:
```bash
# Lire le fichier
tickets=$(cat .forge/backlog/tickets.json)

# Obtenir next_id
next_id=$(echo "$tickets" | jq '.next_id')

# Créer le ticket
new_ticket='{
  "id": "TICKET-'$next_id'",
  "type": "'$type'",
  "title": "'$title'",
  "status": "backlog",
  ...
}'

# Ajouter au fichier
echo "$tickets" | jq ".tickets += [$new_ticket] | .next_id = $((next_id + 1))" > .forge/backlog/tickets.json
```
