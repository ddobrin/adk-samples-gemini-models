# ADK Samples with Gemini Models

This repository contains sample agents built with the Google Agent Development Kit (ADK) using Gemini models, with support for A2A (Agent-to-Agent) protocol and Gemini Enterprise integration.

## Table of Contents
- [Features](#features)
- [Local Development](#local-development)
- [Cloud Run Deployment](#cloud-run-deployment)
- [A2A (Agent-to-Agent) Protocol](#a2a-agent-to-agent-protocol)
- [Gemini Enterprise Integration](#gemini-enterprise-integration)
- [Testing](#testing)
- [Available Agents](#available-agents)

## Features

- **Weather Agent**: Provides weather information for cities worldwide
- **A2A Protocol**: Standardized agent-to-agent communication
- **Custom A2A Endpoint**: Clean responses without tool execution traces
- **Gemini Enterprise**: Full integration with Gemini Enterprise applications
- **Cloud Run Ready**: Automated deployment to Google Cloud Run
- **Service Account Authentication**: No API keys required in production

## Local Development

### Prerequisites

Set environment variables:
```bash
# Required for local development with Gemini models
export GOOGLE_API_KEY=... 
export GOOGLE_CLOUD_PROJECT=...
export GOOGLE_CLOUD_LOCATION=us-central1

# Optional - only if you plan to add agents using these models
# export ANTHROPIC_API_KEY=...
# export OPENAI_API_KEY=...
```

In IDE:
```
GOOGLE_API_KEY=...;GOOGLE_CLOUD_PROJECT=...;GOOGLE_CLOUD_LOCATION=us-central1;ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
```

### Setup

Clone the ADK repo:
```bash
# Clone and checkout specific commit for reproducible builds
# Pinned to commit 7487ab2 (Nov 2, 2025) which includes A2A protocol support
git clone https://github.com/google/adk-java.git
cd adk-java/
git checkout 7487ab21e2318ec6f66c70ca0198e5a5f0364427
./mvnw clean install -DskipTests
```

Clone the samples repo:
```bash
git clone https://github.com/xiangshen-dk/adk-samples-gemini-models.git
cd adk-samples-gemini-models/
mvn clean package
```

### Running Locally

Run samples:
```bash
mvn spring-boot:run -Dspring-boot.run.arguments="--adk.agents.source-dir=<full-path>/adk-samples-gemini-models/"
 
# or 
 
export ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
mvn spring-boot:run
```

Alternatively, uncomment the following line in application.properties and specify the directory:
```
adk.agents.source-dir=...
```

The application starts the AdkWebServer specified in the pom.xml:
```xml
<build>
  <plugins>
    <plugin>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-maven-plugin</artifactId>
      <version>${spring-boot.version}</version>
      <configuration>
        <mainClass>com.google.adk.web.AdkWebServer</mainClass>
      </configuration>
    </plugin>
  </plugins>
</build>
```

## Cloud Run Deployment

### Prerequisites
- Google Cloud Project with billing enabled
- `gcloud` CLI installed and authenticated
- Docker (for local testing, optional)

### Deploy to Cloud Run

The deployment script handles everything automatically:

```bash
# Deploy with a fresh build
./deploy.sh --build

# Deploy using existing image (faster)
./deploy.sh
```

The script will:
1. Enable required Google Cloud APIs
2. Create an Artifact Registry repository
3. Build the Docker image using Cloud Build
4. Create a service account with Vertex AI permissions
5. Deploy to Cloud Run with the service account

### Configuration

Customize the deployment by setting environment variables:

```bash
export GCP_PROJECT_ID=your-project-id
export REGION=us-central1
export SERVICE_NAME=adk-samples-gemini
./deploy.sh --build
```

### Authentication

The Cloud Run service uses Vertex AI models with service account authentication:
- **Service Account**: `adk-samples-runner@PROJECT_ID.iam.gserviceaccount.com`
- **Permissions**: 
  - `roles/aiplatform.user` - Access to Vertex AI models
  - `roles/logging.logWriter` - Write logs to Cloud Logging
- **No API keys required** - Authentication handled via Google Cloud IAM

## A2A (Agent-to-Agent) Protocol

### Overview

This project includes comprehensive support for the Google A2A (Agent-to-Agent) protocol, enabling agents to communicate with each other across services using a standardized JSON-RPC interface.

### Key Features

- **Standardized Communication**: Agents communicate via A2A protocol over HTTP
- **Custom Clean Endpoint**: Special endpoint that filters out tool execution traces
- **Remote Agent Calls**: Call agents deployed on different services
- **Multi-Agent Systems**: Build distributed agent architectures
- **Backward Compatible**: A2A is opt-in and doesn't affect existing functionality

### A2A Endpoints

The service provides three A2A endpoints:

#### 1. Agent Discovery (Agent Card)
```
https://your-service-url/.well-known/agent-card.json
```
Returns agent metadata and capabilities according to A2A specification.

#### 2. Custom Agent Communication (Clean Responses) ✨
```
https://your-service-url/a2a/custom/v1/message:send
```
**This is the recommended endpoint** - Returns only clean, natural language responses without tool execution traces, function calls, or metadata tables.

#### 3. Default Agent Communication
```
https://your-service-url/a2a/remote/v1/message:send
```
Standard ADK endpoint that includes tool execution metadata (useful for debugging).

### Custom A2A Endpoint Benefits

The custom endpoint (`/a2a/custom/v1/message:send`) provides:
- **Clean Responses**: Filters out all tool execution traces
- **Natural Language Only**: Returns only the final agent response
- **Production Ready**: Ideal for user-facing applications
- **Gemini Enterprise Compatible**: Works seamlessly with Gemini Enterprise

### Testing A2A Protocol

#### Test Custom Endpoint (Recommended)

Use the provided test script:
```bash
# Test locally
./test-custom-a2a.sh

# Test on Cloud Run
./test-custom-a2a.sh https://your-service-url
```

#### Manual Testing

```bash
export APP_URL=$(gcloud run services describe adk-samples-gemini \
    --platform managed \
    --region us-central1 \
    --format="value(status.url)")
export TOKEN=$(gcloud auth print-identity-token)

# Test custom endpoint (clean responses)
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/a2a/custom/v1/message:send \
    -H "Content-Type: application/json" \
    -d '{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "message/send",
    "params": {
        "message": {
            "kind": "message",
            "contextId": "test-context",
            "messageId": "test-1",
            "role": "USER",
            "parts": [
                { "kind": "text", "text": "What is the weather in NYC?" }
            ]
        }
    }
}'
```

### A2A Protocol Specification

The A2A protocol uses JSON-RPC 2.0 format:

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "method": "message/send",
  "params": {
    "message": {
      "kind": "message",
      "contextId": "conversation-context-id",
      "messageId": "message-id",
      "role": "USER",
      "parts": [
        { "kind": "text", "text": "Your message here" }
      ]
    }
  }
}
```

**Response (Custom Endpoint):**
```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "result": {
    "role": "agent",
    "parts": [
      { "kind": "text", "text": "The weather in NYC is currently 72°F with partly cloudy skies." }
    ],
    "messageId": "response-message-id",
    "contextId": "conversation-context-id",
    "kind": "message"
  }
}
```

## Gemini Enterprise Integration

### Overview

The `manage-ge-agent.sh` script provides seamless integration with Gemini Enterprise applications, allowing you to register your agents for use within the Gemini Enterprise ecosystem.

### Prerequisites

- `gcloud` CLI installed and authenticated
- `jq` installed for JSON processing
- Access to a Gemini Enterprise application
- Deployed Cloud Run service with A2A support

### Management Script Usage

The script requires the project ID and engine ID as command-line arguments:

```bash
./manage-ge-agent.sh <project-id> <engine-id> <command> [arguments]
```

**Arguments:**
- `project-id` - Your Google Cloud Project ID (required)
- `engine-id` - Your Gemini Enterprise Engine ID (required)
- `command` - The operation to perform: `list`, `register`, or `unregister`

**Optional Environment Variables:**
- `ASSISTANT_ID` - Assistant ID (default: `default_assistant`)
- `COLLECTION_ID` - Collection ID (default: `default_collection`)
- `LOCATION` - Location (default: `global`)

### Commands

#### List Registered Agents
```bash
./manage-ge-agent.sh my-project my-engine-123 list
```

#### Register Your Agent
```bash
# With full agent card URL
./manage-ge-agent.sh my-project my-engine-123 register https://your-service.run.app/.well-known/agent-card.json

# With base URL (automatically appends /.well-known/agent-card.json)
./manage-ge-agent.sh my-project my-engine-123 register https://your-service.run.app
```

#### Unregister an Agent
```bash
./manage-ge-agent.sh my-project my-engine-123 unregister <agent-id>
```

### Complete Workflow Example

1. **Deploy your agent to Cloud Run:**
   ```bash
   ./deploy.sh --build
   ```

2. **Note the service URL from deployment output**

3. **Register with Gemini Enterprise:**
   ```bash
   ./manage-ge-agent.sh your-project your-engine-id \
       register https://your-service-xxxxx-uc.a.run.app
   ```

4. **Verify registration:**
   ```bash
   ./manage-ge-agent.sh your-project your-engine-id list
   ```

5. **Your agent is now available in Gemini Enterprise!**

### Script Features

- **Automatic Project Number Lookup**: Retrieves project number from project ID
- **Smart URL Handling**: Auto-appends `/.well-known/agent-card.json` to base URLs
- **Agent Card Validation**: Validates agent card before registration
- **Secure Authentication**: Uses Google Cloud identity tokens
- **Clear Error Messages**: Helpful debugging with HTTP status codes
- **Colored Output**: Visual feedback for success/errors/warnings

## Testing

### Automated Testing

#### Test Custom A2A Endpoint
```bash
# Test locally
./test-custom-a2a.sh

# Test on Cloud Run
./test-custom-a2a.sh https://your-service-url
```

The test script will:
- Automatically discover the Cloud Run service URL (if deployed)
- Obtain authentication tokens
- Test the WeatherAgent with sample queries
- Verify clean response format (no tool traces)
- Compare custom endpoint vs default endpoint responses

### Manual Testing

#### Get Service Details
```bash
export APP_URL=$(gcloud run services describe adk-samples-gemini \
    --platform managed \
    --region us-central1 \
    --format="value(status.url)")
export TOKEN=$(gcloud auth print-identity-token)
```

#### List Available Agents
```bash
curl -X GET -H "Authorization: Bearer $TOKEN" $APP_URL/list-apps
```

#### Create a Session
```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/apps/WeatherAgent/users/user123/sessions/session_test \
    -H "Content-Type: application/json" \
    -d '{}'
```

#### Send a Message to an Agent
```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/run_sse \
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
}'
```

### Viewing Logs

View Cloud Run logs:
```bash
gcloud run services logs read adk-samples-gemini \
    --region=us-central1 \
    --project=$GCP_PROJECT_ID
```

### Granting Access

To allow specific users to invoke the service:
```bash
gcloud run services add-iam-policy-binding adk-samples-gemini \
    --region=us-central1 \
    --member='user:EMAIL@example.com' \
    --role='roles/run.invoker'
```

## Available Agent

### WeatherAgent

The service provides a **WeatherAgent** that can answer questions about weather conditions in different cities. The agent:
- Uses the Gemini 2.5 Flash model
- Provides weather forecasts for any city
- Returns clean, natural language responses
- Filters out tool execution traces when using the custom A2A endpoint

### Agent Access Methods

The WeatherAgent is accessible through:
1. **Direct API** - Traditional REST endpoints
2. **A2A Protocol** - Standardized agent communication (recommended: `/a2a/custom/v1/message:send`)
3. **Gemini Enterprise** - When registered using the management script

### Example Queries

- "What's the weather in London?"
- "Tell me about the weather in Tokyo"
- "Is it sunny in New York?"
- "What's the temperature in Paris?"

## Configuration

### Environment Variables

Configure the service behavior through environment variables:

```bash
# A2A Protocol
export A2A_ENABLED=true  # Enable/disable A2A support

# Agent Configuration
export AGENT_BASE_URL=https://your-service.run.app
export AGENT_NAME="ADK Multi-Agent Service"
export AGENT_DESCRIPTION="Multi-agent service with weather, time, and science capabilities"
```

### Application Configuration

Configure in `application.yaml`:
```yaml
adk:
  a2a:
    enabled: true
  agents:
    source-dir: /path/to/agents

agent:
  base:
    url: ${AGENT_BASE_URL:http://localhost:8080}
  name: ${AGENT_NAME:ADK Multi-Agent Service}
  description: ${AGENT_DESCRIPTION:Multi-agent service}
```

## Learn More

- [A2A Protocol Specification](https://github.com/google/A2A/)
- [ADK Java Documentation](https://github.com/google/adk-java)
- [ADK Documentation](https://google.github.io/adk-docs/)
- [Gemini Enterprise Documentation](https://docs.cloud.google.com/gemini/enterprise/docs)
