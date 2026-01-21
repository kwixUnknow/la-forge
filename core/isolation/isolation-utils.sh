#!/bin/bash
# Utilitaires pour l'isolation de projets La Forge

REGISTRY_FILE="$HOME/la-forge/core/isolation/project-registry.json"

# Obtenir le prochain ID disponible
get_next_project_id() {
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo "1"
        return
    fi

    local next_id=$(jq -r '.nextId' "$REGISTRY_FILE")
    echo "$next_id"
}

# Enregistrer un nouveau projet
register_project() {
    local project_name="$1"
    local project_type="$2"
    local client_name="$3"

    if [ -z "$project_name" ]; then
        echo "Error: project_name required" >&2
        return 1
    fi

    # Vérifier si le projet existe déjà
    if jq -e ".projects[\"$project_name\"]" "$REGISTRY_FILE" > /dev/null 2>&1; then
        local existing_id=$(jq -r ".projects[\"$project_name\"].id" "$REGISTRY_FILE")
        echo "$existing_id"
        return 0
    fi

    local project_id=$(get_next_project_id)
    local padded_id=$(printf "%02d" $project_id)
    local created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Ajouter au registre
    local tmp_file=$(mktemp)
    jq --arg name "$project_name" \
       --arg id "$padded_id" \
       --arg type "${project_type:-custom}" \
       --arg client "${client_name:-}" \
       --arg created "$created_at" \
       --argjson next_id $((project_id + 1)) \
       '.projects[$name] = {
           "id": $id,
           "type": $type,
           "client": $client,
           "createdAt": $created,
           "ports": {
               "web": (3000 + ($id | tonumber)),
               "api": (5000 + ($id | tonumber)),
               "postgres": (5400 + ($id | tonumber)),
               "redis": (6300 + ($id | tonumber))
           }
       } | .nextId = $next_id' "$REGISTRY_FILE" > "$tmp_file"

    mv "$tmp_file" "$REGISTRY_FILE"
    echo "$padded_id"
}

# Obtenir les infos d'un projet
get_project_info() {
    local project_name="$1"
    jq ".projects[\"$project_name\"]" "$REGISTRY_FILE"
}

# Obtenir les ports d'un projet
get_project_ports() {
    local project_name="$1"
    jq -r ".projects[\"$project_name\"].ports | to_entries | .[] | \"\(.key)=\(.value)\"" "$REGISTRY_FILE"
}

# Lister tous les projets
list_projects() {
    jq -r '.projects | to_entries | .[] | "\(.value.id)\t\(.key)\t\(.value.type)\t\(.value.client)"' "$REGISTRY_FILE" | sort
}

# Générer le fichier .env avec les ports
generate_env_ports() {
    local project_name="$1"
    local output_file="${2:-.env.ports}"

    local info=$(get_project_info "$project_name")

    if [ "$info" = "null" ] || [ -z "$info" ]; then
        echo "Error: Project '$project_name' not found in registry" >&2
        return 1
    fi

    local project_id=$(echo "$info" | jq -r '.id')

    cat > "$output_file" << EOF
# Ports générés automatiquement par La Forge
# Projet: $project_name (ID: $project_id)
# NE PAS MODIFIER - Régénérer avec: forge-isolation generate-env $project_name

PROJECT_ID=$project_id
PROJECT_NAME=$project_name

# Application
WEB_PORT=30${project_id}
API_PORT=50${project_id}

# Databases
POSTGRES_PORT=54${project_id}
REDIS_PORT=63${project_id}
MONGO_PORT=270${project_id}

# Tools
ADMINER_PORT=80${project_id}
MAILHOG_PORT=90${project_id}
PGADMIN_PORT=55${project_id}
EOF

    echo "Generated $output_file for project $project_name (ID: $project_id)"
}

# Main
case "$1" in
    "register")
        register_project "$2" "$3" "$4"
        ;;
    "info")
        get_project_info "$2"
        ;;
    "ports")
        get_project_ports "$2"
        ;;
    "list")
        list_projects
        ;;
    "generate-env")
        generate_env_ports "$2" "$3"
        ;;
    "next-id")
        get_next_project_id
        ;;
    *)
        echo "Usage: $0 {register|info|ports|list|generate-env|next-id} [args...]"
        echo ""
        echo "Commands:"
        echo "  register <name> [type] [client]  - Register a new project"
        echo "  info <name>                      - Get project info"
        echo "  ports <name>                     - Get project ports"
        echo "  list                             - List all projects"
        echo "  generate-env <name> [file]       - Generate .env.ports file"
        echo "  next-id                          - Get next available ID"
        exit 1
        ;;
esac
