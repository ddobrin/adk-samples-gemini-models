#!/bin/bash

# Testing script for ADK Samples on Google Cloud Run
# This script tests the deployed agents via the Cloud Run API

set -e  # Exit on error

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-adk-samples-gemini}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ADK Samples Cloud Run Testing Script ===${NC}"
echo ""

# Validate project ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID is not set and no default project found${NC}"
    echo "Please set GCP_PROJECT_ID environment variable or configure gcloud default project"
    exit 1
fi

# Get the service URL
echo -e "${BLUE}Getting Cloud Run service URL...${NC}"
APP_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --platform managed \
    --region "$REGION" \
    --project="$PROJECT_ID" \
    --format="value(status.url)")

if [ -z "$APP_URL" ]; then
    echo -e "${RED}Error: Could not get service URL. Is the service deployed?${NC}"
    exit 1
fi

echo -e "${GREEN}Service URL:${NC} $APP_URL"
echo ""

# Get authentication token
echo -e "${BLUE}Getting authentication token...${NC}"
TOKEN=$(gcloud auth print-identity-token)
echo -e "${GREEN}✓ Token obtained${NC}"
echo ""

# Test 1: List available apps
echo -e "${BLUE}Test 1: Listing available apps...${NC}"
APPS=$(curl -s -X GET -H "Authorization: Bearer $TOKEN" "$APP_URL/list-apps")
echo -e "${GREEN}Available apps:${NC}"
echo "$APPS" | jq -r '.[]' 2>/dev/null || echo "$APPS"
echo ""

# Test 2: Create a session for WeatherAgent
echo -e "${BLUE}Test 2: Creating session for WeatherAgent...${NC}"
SESSION_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/apps/WeatherAgent/users/user123/sessions/session_test" \
    -H "Content-Type: application/json" \
    -d '{}')
echo -e "${GREEN}Session created:${NC}"
echo "$SESSION_RESPONSE" | jq '.' 2>/dev/null || echo "$SESSION_RESPONSE"
echo ""

# Test 3: Send a message to WeatherAgent
echo -e "${BLUE}Test 3: Sending message to WeatherAgent...${NC}"
echo -e "${YELLOW}Question: What is the weather in NYC?${NC}"
echo ""

RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/run_sse" \
    -H "Content-Type: application/json" \
    -d '{
    "appName": "WeatherAgent",
    "userId": "user123",
    "sessionId": "session_test",
    "newMessage": {
        "role": "user",
        "parts": [{
            "text": "What is the weather in NYC?"
        }]
    },
    "streaming": false
}')

echo -e "${GREEN}Agent Response:${NC}"
# Parse the SSE response and extract the final text response
echo "$RESPONSE" | grep -o '"text":"[^"]*"' | tail -1 | sed 's/"text":"//;s/"$//' || echo "$RESPONSE"
echo ""

# Test 4: Test MultiToolAgent
echo -e "${BLUE}Test 4: Testing MultiToolAgent...${NC}"
echo -e "${YELLOW}Question: What time is it in Tokyo?${NC}"
echo ""

# Create session for MultiToolAgent
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/apps/MultiToolAgent/users/user123/sessions/session_multi" \
    -H "Content-Type: application/json" \
    -d '{}' > /dev/null

MULTI_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$APP_URL/run_sse" \
    -H "Content-Type: application/json" \
    -d '{
    "appName": "MultiToolAgent",
    "userId": "user123",
    "sessionId": "session_multi",
    "newMessage": {
        "role": "user",
        "parts": [{
            "text": "What time is it in Tokyo?"
        }]
    },
    "streaming": false
}')

echo -e "${GREEN}Agent Response:${NC}"
echo "$MULTI_RESPONSE" | grep -o '"text":"[^"]*"' | tail -1 | sed 's/"text":"//;s/"$//' || echo "$MULTI_RESPONSE"
echo ""

echo -e "${GREEN}=== Testing Complete ===${NC}"
echo ""
echo -e "${YELLOW}Service URL:${NC} $APP_URL"
echo -e "${YELLOW}Available Apps:${NC} $APPS"
echo ""
echo -e "${YELLOW}To test manually:${NC}"
echo "  export APP_URL=$APP_URL"
echo "  export TOKEN=\$(gcloud auth print-identity-token)"
echo "  curl -X GET -H \"Authorization: Bearer \$TOKEN\" \$APP_URL/list-apps"
echo ""
