# A2A Agent Deployment Guide

## Overview

This guide explains how to deploy your A2A-compliant agent to Google Cloud Run and register it with Gemini Enterprise.

## Prerequisites

- Google Cloud Project with billing enabled
- `gcloud` CLI installed and configured
- Discovery Engine Admin role (`roles/discoveryengine.admin`)
- Existing Gemini Enterprise app

## Step 1: Configure Environment Variables

Before deploying, set the agent base URL in your deployment configuration.

### For Cloud Run Deployment

Update your `deploy.sh` script or set environment variables:

```bash
export AGENT_BASE_URL="https://your-service-name-abc123-uc.a.run.app"
export AGENT_NAME="ADK Multi-Agent Service"
export AGENT_DESCRIPTION="Multi-agent service with weather, time, and science capabilities"
export AGENT_VERSION="1.0.0"
```

### For Local Testing

```bash
export AGENT_BASE_URL="http://localhost:8080"
```

## Step 2: Deploy to Cloud Run

### Option A: Using the deploy.sh script

```bash
./deploy.sh
```

### Option B: Manual deployment

```bash
# Build the application
mvn clean package -DskipTests

# Deploy to Cloud Run
gcloud run deploy adk-agent-service \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars AGENT_BASE_URL=https://your-service-abc123-uc.a.run.app,\
GOOGLE_CLOUD_PROJECT=your-project-id,\
VERTEX_AI_LOCATION=us-central1
```

**Important**: After deployment, update the `AGENT_BASE_URL` environment variable with your actual Cloud Run service URL.

## Step 3: Verify Agent Card

Test that your agent card is accessible and valid:

```bash
# Get your Cloud Run service URL
SERVICE_URL=$(gcloud run services describe adk-agent-service \
  --region us-central1 \
  --format 'value(status.url)')

# Fetch the agent card
curl "${SERVICE_URL}/.well-known/agent-card.json" | jq .
```

Expected output should match the A2A specification:

```json
{
  "protocolVersion": "v1.0",
  "name": "ADK Multi-Agent Service",
  "description": "Multi-agent service with weather, time, and science capabilities",
  "url": "https://your-service-abc123-uc.a.run.app",
  "version": "1.0.0",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false
  },
  "defaultInputModes": ["text/plain"],
  "defaultOutputModes": ["text/plain"],
  "skills": [...]
}
```

## Step 4: Register Agent with Gemini Enterprise

### Option A: Using Google Cloud Console

1. Go to the [Gemini Enterprise page](https://console.cloud.google.com/gemini-enterprise/)
2. Click the name of your app
3. Click **Agents > Add Agents**
4. Select **Custom agent via A2A**
5. Paste your agent card JSON
6. Click **Import Agent > Next**
7. Configure authorization if needed
8. Click **Finish**

### Option B: Using REST API

```bash
# Set variables
PROJECT_NUMBER="your-project-number"
APP_ID="your-app-id"
LOCATION="global"  # or "us" or "eu"
ENDPOINT_LOCATION="global-"  # or "us-" or "eu-"

# Get your agent card
AGENT_CARD=$(curl -s "${SERVICE_URL}/.well-known/agent-card.json")

# Escape the JSON for the API call
ESCAPED_CARD=$(echo "$AGENT_CARD" | jq -c . | sed 's/"/\\"/g')

# Register the agent
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${ENDPOINT_LOCATION}discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/${LOCATION}/collections/default_collection/engines/${APP_ID}/assistants/default_assistant/agents" \
  -d "{
    \"name\": \"ADK Multi-Agent Service\",
    \"displayName\": \"ADK Multi-Agent Service\",
    \"description\": \"Multi-agent service with weather, time, and science capabilities\",
    \"a2aAgentDefinition\": {
      \"jsonAgentCard\": \"${ESCAPED_CARD}\"
    }
  }"
```

## Step 5: Configure Authentication (Optional)

If your agent needs to access Google Cloud resources on behalf of users:

### Create OAuth Credentials

1. Go to [APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials)
2. Select the project with your data sources
3. Click **Create credentials > OAuth client ID**
4. Select **Web application**
5. Add authorized redirect URIs:
   - `https://vertexaisearch.cloud.google.com/oauth-redirect`
   - `https://vertexaisearch.cloud.google.com/static/oauth/oauth.html`
6. Download the JSON credentials

### Register Authorization Resource

```bash
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://${ENDPOINT_LOCATION}discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/authorizations?authorizationId=my-auth" \
  -d '{
    "name": "projects/'${PROJECT_ID}'/locations/'${LOCATION}'/authorizations/my-auth",
    "serverSideOauth2": {
      "clientId": "YOUR_OAUTH_CLIENT_ID",
      "clientSecret": "YOUR_OAUTH_CLIENT_SECRET",
      "authorizationUri": "YOUR_OAUTH_AUTH_URI",
      "tokenUri": "YOUR_OAUTH_TOKEN_URI"
    }
  }'
```

### Update Agent Registration

Add the authorization configuration when registering the agent:

```json
{
  "authorization_config": {
    "agent_authorization": "projects/PROJECT_NUMBER/locations/LOCATION/authorizations/my-auth"
  }
}
```

## Step 6: Test the Agent

1. Open your Gemini Enterprise app in the web interface
2. The agent should appear in the available agents list
3. Try example queries from the skills:
   - "What is the weather in London?"
   - "What time is it?"
   - "Explain photosynthesis"

## Troubleshooting

### Agent Card Not Accessible

```bash
# Check Cloud Run service status
gcloud run services describe adk-agent-service --region us-central1

# Check logs
gcloud run services logs read adk-agent-service --region us-central1
```

### Agent Not Appearing in Gemini Enterprise

1. Verify the agent card is valid JSON
2. Check that all required fields are present
3. Ensure the `url` field matches your Cloud Run service URL
4. Verify you have the Discovery Engine Admin role

### Authentication Issues

1. Verify OAuth credentials are correctly configured
2. Check that redirect URIs are exactly as specified
3. Ensure the authorization resource is created in the correct project

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `AGENT_BASE_URL` | Base URL of the deployed agent | `http://localhost:8080` | Yes (for Cloud Run) |
| `AGENT_NAME` | Display name of the agent | `ADK Multi-Agent Service` | No |
| `AGENT_DESCRIPTION` | Agent description | Multi-agent service... | No |
| `AGENT_VERSION` | Agent version | `1.0.0` | No |
| `GOOGLE_CLOUD_PROJECT` | GCP Project ID | - | Yes |
| `VERTEX_AI_LOCATION` | Vertex AI location | `us-central1` | No |

## Next Steps

- Monitor agent usage in Gemini Enterprise
- Update agent skills as needed
- Configure additional authentication if required
- Set up monitoring and logging for production use

## References

- [Official A2A Specification](https://a2a-protocol.org/latest/specification/)
- [Google Cloud Documentation](https://docs.cloud.google.com/gemini/enterprise/docs/register-and-manage-an-a2a-agent)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
