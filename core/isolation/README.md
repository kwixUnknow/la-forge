# Système d'Isolation de Projets

## Vue d'ensemble

Chaque projet créé par La Forge est **complètement isolé** :
- Environnement Docker dédié
- Ports uniques (pas de conflit)
- Dépendances isolées (venv Python, node_modules)
- Schémas/tags dédiés pour services partagés

## Convention de Ports

Chaque projet reçoit un **identifiant numérique unique (01-99)** qui préfixe tous ses ports :

```
Projet 01 (sportcoach):
  - App:      3001 (web), 5001 (api)
  - DB:       5401 (postgres), 2701 (redis)
  - Tools:    8001 (adminer), 9001 (mailhog)

Projet 02 (marketplace):
  - App:      3002 (web), 5002 (api)
  - DB:       5402 (postgres), 2702 (redis)
  - Tools:    8002 (adminer), 9002 (mailhog)
```

### Mapping Standard

| Service       | Port Base | Format Projet |
|---------------|-----------|---------------|
| Web App       | 3000      | 30XX          |
| API           | 5000      | 50XX          |
| PostgreSQL    | 5432      | 54XX          |
| Redis         | 6379      | 63XX ou 27XX  |
| MongoDB       | 27017     | 270XX         |
| Adminer       | 8080      | 80XX          |
| MailHog       | 8025      | 90XX          |
| PgAdmin       | 5050      | 55XX          |

## Services Partagés

Pour les services lourds (ex: PostgreSQL principal), on utilise des **schémas/databases dédiés** :

```sql
-- PostgreSQL partagé
CREATE DATABASE project_sportcoach;
CREATE DATABASE project_marketplace;

-- Ou schémas dans même DB
CREATE SCHEMA sportcoach;
CREATE SCHEMA marketplace;
```

## Tagging AWS

Tous les projets **DOIVENT** avoir ces tags sur leurs ressources AWS :

```hcl
tags = {
  Project     = "sportcoach"        # Identifiant unique
  Environment = "dev|staging|prod"
  Owner       = "thomas"
  CostCenter  = "client-name"       # Pour facturation
  ManagedBy   = "terraform"
  CreatedBy   = "la-forge"
}
```

## Fichiers

- `project-registry.json` - Registre de tous les projets et leurs IDs
- `docker-compose.base.yml` - Template Docker Compose
- `isolation-utils.sh` - Scripts utilitaires
