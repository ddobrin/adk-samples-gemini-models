#!/bin/bash

# Script to manage agents in Gemini Enterprise
# Usage:
#   ./manage-ge-agent.sh <project-id> <engine-id> list
#   ./manage-ge-agent.sh <project-id> <engine-id> register <agent-card-url>
#   ./manage-ge-agent.sh <project-id> <engine-id> unregister <agent-id>

set -e

# Colors for output - define early
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
print_usage() {
    echo "Usage: $0 <project-id> <engine-id> <command> [arguments]"
    echo ""
    echo "Arguments:"
    echo "  project-id        Google Cloud Project ID"
    echo "  engine-id         Gemini Enterprise Engine ID"
    echo ""
    echo "Commands:"
    echo "  list                          List all registered agents"
    echo "  register <agent-card-url>     Register a new agent using its agent card URL"
    echo "  unregister <agent-id>         Unregister an agent by ID"
    echo ""
    echo "Optional Environment Variables:"
    echo "  ASSISTANT_ID      - Assistant ID (default: default_assistant)"
    echo "  COLLECTION_ID     - Collection ID (default: default_collection)"
    echo "  LOCATION          - Location (default: global)"
    echo ""
    echo "Examples:"
    echo "  $0 my-project my-engine-123 list"
    echo "  $0 my-project my-engine-123 register https://your-service.run.app/.well-known/agent-card.json"
    echo "  $0 my-project my-engine-123 unregister 4857216686933843906"
}

# Function to get project number from project ID
get_project_number() {
    local project_id="$1"
    echo "Getting project number for project: $project_id" >&2
    
    set +e
    local project_number=$(gcloud projects describe "$project_id" --format="value(projectNumber)" 2>&1)
    local gcloud_exit=$?
    set -e
    
    if [ $gcloud_exit -ne 0 ]; then
        echo -e "${RED}Error: Failed to get project number for project '$project_id'${NC}" >&2
        echo -e "${RED}gcloud output: $project_number${NC}" >&2
        exit 1
    fi
    
    if [ -z "$project_number" ]; then
        echo -e "${RED}Error: Empty project number for project '$project_id'${NC}" >&2
        exit 1
    fi
    
    echo "$project_number"
}

# Function to list agents
list_agents() {
    echo -e "${GREEN}Listing registered agents...${NC}"
    echo "URL: $BASE_URL"
    echo ""
    
    curl -X GET \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        -H "X-Goog-User-Project: ${GCP_PROJECT_ID}" \
        "$BASE_URL" | jq .
}

# Function to fetch and parse agent card
fetch_agent_card() {
    local agent_card_url="$1"
    
    # Validate URL format
    if [[ ! "$agent_card_url" =~ /.well-known/agent-card.json$ ]]; then
        echo -e "${YELLOW}Warning: URL should end with '/.well-known/agent-card.json'${NC}" >&2
        echo -e "${YELLOW}Provided URL: $agent_card_url${NC}" >&2
        echo "" >&2
        read -p "Do you want to append '/.well-known/agent-card.json' to the URL? (y/n): " append_path
        if [[ "$append_path" =~ ^[Yy]$ ]]; then
            # Remove trailing slash if present
            agent_card_url="${agent_card_url%/}"
            agent_card_url="${agent_card_url}/.well-known/agent-card.json"
            echo -e "${GREEN}Using URL: $agent_card_url${NC}" >&2
        fi
    fi
    
    echo "Fetching agent card from: ${agent_card_url}" >&2
    echo "" >&2
    
    # Get authentication token first
    echo "Getting authentication token..." >&2
    set +e
    local token=$(gcloud auth print-identity-token 2>&1)
    local token_exit=$?
    set -e
    
    if [ $token_exit -ne 0 ]; then
        echo "Error: Failed to get authentication token" >&2
        echo "gcloud output: $token" >&2
        exit 1
    fi
    
    if [ -z "$token" ]; then
        echo "Error: Empty authentication token" >&2
        exit 1
    fi
    echo "Token obtained successfully (length: ${#token})" >&2
    echo "" >&2
    
    # Temporarily disable exit on error for curl
    set +e
    # Fetch the agent card with authentication token
    local http_code=$(curl -s -w "%{http_code}" -o /tmp/agent_card_response.json \
        -H "Authorization: Bearer $token" \
        "$agent_card_url")
    local curl_exit=$?
    set -e
    
    if [ $curl_exit -ne 0 ]; then
        echo -e "${RED}Error: curl command failed with exit code $curl_exit${NC}" >&2
        rm -f /tmp/agent_card_response.json
        exit 1
    fi
    
    local agent_card=""
    if [ -f /tmp/agent_card_response.json ]; then
        agent_card=$(cat /tmp/agent_card_response.json)
    fi
    
    echo "HTTP Status Code: $http_code" >&2
    echo "Response length: ${#agent_card} bytes" >&2
    echo "" >&2
    
    if [ "$http_code" != "200" ]; then
        echo -e "${RED}Error: Failed to fetch agent card (HTTP $http_code)${NC}" >&2
        echo -e "${RED}Response:${NC}" >&2
        echo "$agent_card" >&2
        rm -f /tmp/agent_card_response.json
        exit 1
    fi
    
    if [ -z "$agent_card" ]; then
        echo -e "${RED}Error: Empty response from $agent_card_url${NC}" >&2
        rm -f /tmp/agent_card_response.json
        exit 1
    fi
    
    # Validate it's valid JSON
    if ! echo "$agent_card" | jq . > /dev/null 2>&1; then
        echo -e "${RED}Error: Agent card is not valid JSON${NC}" >&2
        echo -e "${RED}Response received:${NC}" >&2
        echo "$agent_card" >&2
        echo "" >&2
        echo -e "${YELLOW}Tip: Make sure the URL ends with '/.well-known/agent-card.json'${NC}" >&2
        rm -f /tmp/agent_card_response.json
        exit 1
    fi
    
    rm -f /tmp/agent_card_response.json
    
    # Validate it has required fields
    local has_name=$(echo "$agent_card" | jq -r '.name // empty')
    if [ -z "$has_name" ]; then
        echo -e "${RED}Error: Agent card is missing required 'name' field${NC}" >&2
        echo -e "${RED}Agent card content:${NC}" >&2
        echo "$agent_card" | jq . >&2
        exit 1
    fi
    
    # Only output the agent card JSON to stdout
    echo "$agent_card"
}

# Function to register an agent
register_agent() {
    local agent_card_url="$1"
    
    if [ -z "$agent_card_url" ]; then
        echo -e "${RED}Error: Agent card URL is required${NC}"
        print_usage
        exit 1
    fi
    
    # Fetch the agent card
    local agent_card=$(fetch_agent_card "$agent_card_url")
    
    # Extract name and description from agent card
    local agent_name=$(echo "$agent_card" | jq -r '.name // "Unknown Agent"')
    local agent_description=$(echo "$agent_card" | jq -r '.description // "No description"')
    
    echo -e "${GREEN}Registering agent: ${agent_name}${NC}"
    echo "Description: $agent_description"
    echo ""
    
    # Escape the agent card JSON for embedding in the request
    local escaped_agent_card=$(echo "$agent_card" | jq -c . | sed 's/"/\\"/g')
    
    # Create the registration request
    local request_body=$(cat <<EOF
{
    "displayName": "${agent_name}",
    "description": "${agent_description}",
    "a2aAgentDefinition": {
       "jsonAgentCard": "${escaped_agent_card}"
    }
}
EOF
)
    
    echo "Sending registration request..."
    echo ""
    
    # Register the agent
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        -H "X-Goog-User-Project: ${GCP_PROJECT_ID}" \
        "$BASE_URL" \
        -d "$request_body")
    
    # Check if registration was successful
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo -e "${RED}Error registering agent:${NC}"
        echo "$response" | jq .
        exit 1
    else
        echo -e "${GREEN}Agent registered successfully!${NC}"
        echo "$response" | jq .
        
        # Extract and display the agent ID
        local agent_id=$(echo "$response" | jq -r '.name' | awk -F'/' '{print $NF}')
        echo ""
        echo -e "${YELLOW}Agent ID: ${agent_id}${NC}"
        echo "To unregister: $0 $GCP_PROJECT_ID $ENGINE_ID unregister ${agent_id}"
    fi
}

# Function to unregister an agent
unregister_agent() {
    local agent_id="$1"
    
    if [ -z "$agent_id" ]; then
        echo -e "${RED}Error: Agent ID is required${NC}"
        print_usage
        exit 1
    fi
    
    echo -e "${YELLOW}Unregistering agent: ${agent_id}${NC}"
    echo "URL: ${BASE_URL}/${agent_id}"
    echo ""
    
    local response=$(curl -s -X DELETE \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        -H "X-Goog-User-Project: ${GCP_PROJECT_ID}" \
        "${BASE_URL}/${agent_id}")
    
    # Check if unregistration was successful
    if [ -z "$response" ] || echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        if [ -z "$response" ]; then
            echo -e "${GREEN}Agent unregistered successfully!${NC}"
        else
            echo -e "${RED}Error unregistering agent:${NC}"
            echo "$response" | jq .
            exit 1
        fi
    else
        echo -e "${GREEN}Agent unregistered successfully!${NC}"
        echo "$response" | jq .
    fi
}

# Main script logic
if [ $# -lt 3 ]; then
    print_usage
    exit 1
fi

# Get required arguments
GCP_PROJECT_ID="$1"
ENGINE_ID="$2"
COMMAND="$3"

# Validate project ID and engine ID
if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID is required${NC}"
    print_usage
    exit 1
fi

if [ -z "$ENGINE_ID" ]; then
    echo -e "${RED}Error: Engine ID is required${NC}"
    print_usage
    exit 1
fi

# Get project number from project ID
PROJECT_NUMBER=$(get_project_number "$GCP_PROJECT_ID")

# Set defaults for optional parameters
ASSISTANT_ID="${ASSISTANT_ID:-default_assistant}"
COLLECTION_ID="${COLLECTION_ID:-default_collection}"
LOCATION="${LOCATION:-global}"

# Display configuration
echo -e "${GREEN}Configuration:${NC}"
echo "  Project ID:     $GCP_PROJECT_ID"
echo "  Project Number: $PROJECT_NUMBER"
echo "  Engine ID:      $ENGINE_ID"
echo "  Assistant ID:   $ASSISTANT_ID"
echo "  Collection ID:  $COLLECTION_ID"
echo "  Location:       $LOCATION"
echo ""

# Construct base URL
BASE_URL="https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/${LOCATION}/collections/${COLLECTION_ID}/engines/${ENGINE_ID}/assistants/${ASSISTANT_ID}/agents"

case "$COMMAND" in
    list)
        list_agents
        ;;
    register)
        register_agent "$4"
        ;;
    unregister)
        unregister_agent "$4"
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac
