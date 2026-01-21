# /forge-orchestrator:team - Lance l'équipe d'agents

Lance l'équipe multi-agents dans des terminaux tmux séparés pour développer en autonomie.

## Usage

```
/forge-orchestrator:team [project-path]
```

## Paramètres

- `project-path` (optionnel): Chemin vers le projet. Par défaut: répertoire courant.

## Pré-requis

1. **tmux installé**: `brew install tmux` (macOS) ou `apt install tmux` (Linux)
2. **Forge initialisé**: Le projet doit avoir un dossier `.forge/`
3. **Tickets dans le backlog**: Au moins un ticket dans `.forge/backlog/tickets.json`

## Ce que fait cette commande

1. Vérifie que `.forge/` existe (sinon, propose d'initialiser)
2. Vérifie que tmux est installé
3. Lance 4 agents dans des panes tmux séparés:
   - **supervisor** (Opus) - Coordonne l'équipe
   - **developer** (Sonnet) - Implémente les tickets
   - **code-reviewer** (Sonnet) - Review le code
   - **qa-tester** (Haiku) - Teste les implémentations
4. Configure le layout 2x2
5. Attache au session tmux

## Workflow

```
Tu lances /forge-orchestrator:team
    ↓
4 terminaux s'ouvrent avec chaque agent
    ↓
supervisor lit le backlog et assigne les tickets
    ↓
developer implémente, passe en review
    ↓
code-reviewer review, passe en testing
    ↓
qa-tester teste, passe en done (ou crée bug)
    ↓
Le cycle continue jusqu'à backlog vide
```

## Commandes tmux utiles

| Action | Raccourci |
|--------|-----------|
| Changer de pane | `Ctrl+B` puis flèches |
| Détacher | `Ctrl+B` puis `D` |
| Réattacher | `tmux attach -t forge-{project}` |
| Fermer session | `tmux kill-session -t forge-{project}` |

## Outils complémentaires

### Dashboard (dans un autre terminal)
```bash
~/la-forge/core/scripts/forge-dashboard.sh . --watch
```

### Watcher (notifications)
```bash
~/la-forge/core/scripts/forge-watcher.sh .
```

## Exemple de session

```bash
# 1. Aller dans le projet
cd ~/mon-projet

# 2. Vérifier que forge est initialisé
ls .forge/

# 3. Ajouter un ticket si nécessaire
# Éditer .forge/backlog/tickets.json

# 4. Lancer l'équipe
/forge-orchestrator:team

# 5. Détacher pour laisser les agents travailler
# Ctrl+B puis D

# 6. Suivre la progression
~/la-forge/core/scripts/forge-dashboard.sh . --watch
```

## Comportement attendu

Quand tu utilises cette commande:

1. **Si .forge/ n'existe pas**:
   ```
   Proposer: "Voulez-vous initialiser Forge pour ce projet?"
   Si oui: exécuter forge-init.sh
   ```

2. **Si tmux n'est pas installé**:
   ```
   Afficher les commandes pour lancer manuellement chaque agent
   ```

3. **Si tout est OK**:
   ```
   Exécuter: ~/la-forge/core/scripts/forge-team.sh {project-path}
   ```

## Notes

- Les agents communiquent via `.forge/agent-state/{agent}/inbox.json` et `outbox.json`
- Les transitions sont automatiques grâce aux hooks
- Le supervisor coordonne mais n'a pas besoin d'intervenir constamment
- Tu peux interagir avec n'importe quel agent dans son pane
