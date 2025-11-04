# ADK Samples with Gemini Models

This repository contains sample agents built with the Google Agent Development Kit (ADK) using Gemini models.

## Table of Contents
- [Local Development](#local-development)
- [Cloud Run Deployment](#cloud-run-deployment)
- [Testing](#testing)

## Local Development

### Set environment variables
```bash
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=... 
export GOOGLE_API_KEY=... 
export GOOGLE_CLOUD_PROJECT=...
export GOOGLE_CLOUD_LOCATION=us-central1
```

In IDE:
```aiexclude
ANTHROPIC_API_KEY=...;OPENAI_API_KEY=...;GOOGLE_API_KEY=...;ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
```

Clone the ADK repo
```aiexclude
# Clone and checkout specific commit for reproducible builds
# Pinned to commit 7487ab2 (Nov 2, 2025) which includes A2A protocol support
git clone https://github.com/google/adk-java.git
cd adk-java/
git checkout 7487ab21e2318ec6f66c70ca0198e5a5f0364427
./mvnw clean install -DskipTests
```

Clone the samples repo
```aiexclude
git clone https://github.com/ddobrin/adk-samples-gemini-models.git
cd adk-samples-gemini-models/
mvn clean package
```

Run samples
```aiexclude
mvn spring-boot:run -Dspring-boot.run.arguments="--adk.agents.source-dir=<full-path>/adk-samples-gemini-models/"
 
 or 
 
export ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
mvn spring-boot:run
```

Alternatively, uncomment the following line in application.properties and specify the directory
```aiexclude
adk.agents.source-dir=...
```

It starts the AdkWebServer specified in the pom.xml
```xml
...
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
...
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

You can customize the deployment by setting environment variables:

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

## Testing

### Automated Testing

Run the automated test script to verify your deployment:

```bash
./test-cloud-run.sh
```

This script will:
1. Automatically discover the Cloud Run service URL
2. Obtain authentication token
3. List available agents
4. Test the WeatherAgent with a sample query
5. Test the MultiToolAgent with a time query

### Manual Testing

Get the service URL and authentication token:

```bash
export APP_URL=$(gcloud run services describe adk-samples-gemini \
    --platform managed \
    --region us-central1 \
    --format="value(status.url)")
export TOKEN=$(gcloud auth print-identity-token)
```

List available agents:

```bash
curl -X GET -H "Authorization: Bearer $TOKEN" $APP_URL/list-apps
```

Create a session:

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/apps/WeatherAgent/users/user123/sessions/session_test \
    -H "Content-Type: application/json" \
    -d '{}'
```

Send a message to an agent:

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

### Available Agents

- **WeatherAgent** - Provides weather information for cities
- **MultiToolAgent** - Answers questions about time and weather
- **LoopingIterativeWritingPipeline** - Iterative document writing with critique
- **ScienceAgent-ADK** - Science teaching assistant

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

## A2A (Agent-to-Agent) Protocol

### Overview

This project includes support for the Google A2A (Agent-to-Agent) protocol, enabling agents to communicate with each other across services using a standardized JSON-RPC interface.

### Features

- **Standardized Communication**: Agents communicate via A2A protocol over HTTP
- **Remote Agent Calls**: Call agents deployed on different services
- **Multi-Agent Systems**: Build distributed agent architectures
- **Clean Responses**: Custom endpoint filters out tool execution traces
- **Backward Compatible**: A2A is opt-in and doesn't affect existing functionality

### A2A Endpoints

When deployed, the service provides three A2A endpoints:

**Agent Discovery (Agent Card)**
```
https://your-service-url/.well-known/agent-card.json
```

**Custom Agent Communication (Clean Responses)**
```
https://your-service-url/a2a/custom/v1/message:send
```
This endpoint filters out tool execution traces and returns only clean, natural language responses.

**Default Agent Communication**
```
https://your-service-url/a2a/remote/v1/message:send
```
This endpoint includes tool execution metadata (useful for debugging).

### Configuration

A2A is enabled by default. To disable it, set the environment variable:

```bash
export A2A_ENABLED=false
```

Or configure in `application.yaml`:

```yaml
adk:
  a2a:
    enabled: false
```

### Testing A2A Protocol

Test the A2A endpoint with curl:

```bash
export APP_URL=$(gcloud run services describe adk-samples-gemini \
    --platform managed \
    --region us-central1 \
    --format="value(status.url)")
export TOKEN=$(gcloud auth print-identity-token)

curl -X POST -H "Authorization: Bearer $TOKEN" \
    $APP_URL/a2a/remote/v1/message:send \
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

### Agent-to-Agent Communication

#### Local Agent Communication

Agents within the same service can communicate directly:

```java
// Create specialized agents
BaseAgent weatherAgent = LlmAgent.builder()
    .name("WeatherSpecialist")
    .model("gemini-2.5-flash")
    .tools(weatherTool)
    .build();

BaseAgent timeAgent = LlmAgent.builder()
    .name("TimeSpecialist")
    .model("gemini-2.5-flash")
    .tools(timeTool)
    .build();

// Coordinator agent that uses both
BaseAgent coordinator = SequentialAgent.builder()
    .name("Coordinator")
    .subAgents(weatherAgent, timeAgent)
    .build();
```

#### Remote Agent Communication

Call agents on remote services via A2A:

```java
// Configure remote agent URL
String remoteAgentUrl = "https://remote-service/a2a/remote/v1";

// The ADK framework handles remote calls automatically
// when agents are configured with remote URLs
```

### Example Agents

The project includes A2A example agents:

- **A2AMultiAgentExample**: Demonstrates local multi-agent coordination
- **RemoteA2AAgentExample**: Shows how to configure remote agent calls

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

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "result": {
    "role": "agent",
    "parts": [
      { "kind": "text", "text": "Agent response here" }
    ],
    "messageId": "response-message-id",
    "contextId": "conversation-context-id",
    "kind": "message"
  }
}
```

### Benefits of A2A

1. **Standardization**: Common protocol for agent communication
2. **Interoperability**: Agents from different teams/services can communicate
3. **Scalability**: Distribute agents across multiple services
4. **Flexibility**: Mix local and remote agents in the same system
5. **Debugging**: Standard format makes debugging easier

### Learn More

- [A2A Protocol Specification](https://github.com/google/A2A/)
- [ADK Java A2A Documentation](https://github.com/google/adk-java/tree/main/a2a)
- [ADK Documentation](https://google.github.io/adk-docs/)

## Gemini Enterprise Agent Management

### Overview

The `manage-ge-agent.sh` script provides a convenient way to manage agents in Gemini Enterprise applications. It supports listing, registering, and unregistering agents.

### Prerequisites

- `gcloud` CLI installed and authenticated
- `jq` installed for JSON processing
- Access to a Gemini Enterprise application

### Configuration

The script will prompt you for required configuration values when you run it. You can also set these values via environment variables to skip the prompts:

```bash
export GCP_PROJECT_ID="your-project-id"
export PROJECT_NUMBER="your-project-number"
export ENGINE_ID="your-engine-id"
export ASSISTANT_ID="default_assistant"  # Optional, defaults to "default_assistant"
export COLLECTION_ID="default_collection"  # Optional, defaults to "default_collection"
export LOCATION="global"  # Optional, defaults to "global"
```

**Required Values:**
- `GCP_PROJECT_ID` - Your Google Cloud Project ID
- `PROJECT_NUMBER` - Your Google Cloud Project Number
- `ENGINE_ID` - Your Gemini Enterprise Engine ID

**Optional Values (with defaults):**
- `ASSISTANT_ID` - Assistant ID (default: `default_assistant`)
- `COLLECTION_ID` - Collection ID (default: `default_collection`)
- `LOCATION` - Location (default: `global`)

### Usage

**List all registered agents:**
```bash
./manage-ge-agent.sh list
```

**Register a new agent:**
```bash
./manage-ge-agent.sh register https://your-service.run.app/.well-known/agent-card.json
```

The script will:
1. Fetch the agent card from the URL
2. Extract the agent name and description
3. Register the agent with Gemini Enterprise
4. Display the agent ID for future reference

**Unregister an agent:**
```bash
./manage-ge-agent.sh unregister <agent-id>
```

### Example Workflow

1. Deploy your agent to Cloud Run:
   ```bash
   ./deploy.sh --build
   ```

2. Get the agent card URL from the deployment output

3. Register the agent with Gemini Enterprise:
   ```bash
   ./manage-ge-agent.sh register https://adk-samples-gemini-sbgivfobaa-uc.a.run.app/.well-known/agent-card.json
   ```

4. List registered agents to verify:
   ```bash
   ./manage-ge-agent.sh list
   ```

5. To unregister later:
   ```bash
   ./manage-ge-agent.sh unregister <agent-id>
   ```

### Features

- **Automatic Agent Card Fetching**: Fetches and validates the agent card from the provided URL
- **JSON Validation**: Ensures the agent card is valid JSON before registration
- **Error Handling**: Provides clear error messages for common issues
- **Colored Output**: Uses colors to highlight success, errors, and warnings
- **Configurable**: All parameters can be set via environment variables
