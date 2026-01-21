---
description: Check status of all projects managed by La Forge
allowed-tools: Read, Bash, Glob
---

# Status des Projets

## Contexte
Affiche un aperçu de tous les projets gérés avec leurs informations d'isolation.

## Actions

### 1. Lister les Projets du Registre

```bash
# Affiche les projets enregistrés avec leurs IDs et ports
~/la-forge/core/isolation/isolation-utils.sh list
```

### 2. Pour chaque projet enregistré, récupérer :
- ID d'isolation
- Nom du projet
- Type
- Client associé
- Ports assignés

### 3. Vérifier l'état de chaque projet

```bash
# Pour chaque projet dans le registre
for projet in $(jq -r '.projects | keys[]' ~/la-forge/core/isolation/project-registry.json); do
  if [ -d ~/$projet ]; then
    cd ~/$projet
    # Git status
    # Docker status
  fi
done
```

### 4. Format de sortie

```
📊 Projets La Forge

┌─────────────────────────────────────────────────────────────┐
│ 📁 sportcoach                          [ID: 01] [client-x]  │
│ Type: webapp-nextjs                                          │
│ Ports: web=3001 api=5001 pg=5401 redis=6301                 │
│ Docker: ✅ 3/3 running                                       │
│ Branch: main (clean)                                         │
│ Last: 2 days ago - "feat: add user authentication"          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📁 dataplatform                        [ID: 02] [client-y]  │
│ Type: data-pipeline-aws                                      │
│ Ports: N/A (serverless)                                      │
│ AWS: 12 resources tagged                                     │
│ Branch: feature/etl (3 uncommitted)                         │
│ Last: 5 hours ago - "wip: optimizing glue job"              │
└─────────────────────────────────────────────────────────────┘

Total: 2 projets enregistrés
```

### 5. Vérifications Isolation

Pour chaque projet, vérifier :
- [ ] Ports uniques (pas de conflit)
- [ ] Containers utilisent les bons préfixes
- [ ] Dépendances locales (.venv ou node_modules présent)
- [ ] .env.ports existe et est cohérent

## Arguments
$ARGUMENTS - Filtre optionnel (nom de projet ou type)
