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
git clone https://github.com/ddobrin/adk-java.git
cd adk-java/
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
