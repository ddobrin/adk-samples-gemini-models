#!/bin/bash

# Deployment script for ADK Samples to Google Cloud Run
# This script builds the Docker image using Cloud Build and deploys to Cloud Run

set -e  # Exit on error

# Parse command-line arguments
BUILD_IMAGE="${BUILD_IMAGE:-false}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_IMAGE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--build]"
            exit 1
            ;;
    esac
done

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-adk-samples-gemini}"
REPOSITORY_NAME="${REPOSITORY_NAME:-adk-samples}"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ADK Samples Deployment Script ===${NC}"
echo ""

# Validate project ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID is not set and no default project found${NC}"
    echo "Please set GCP_PROJECT_ID environment variable or configure gcloud default project"
    exit 1
fi

echo -e "${YELLOW}Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}Region:${NC} $REGION"
echo -e "${YELLOW}Service Name:${NC} $SERVICE_NAME"
echo -e "${YELLOW}Repository:${NC} $REPOSITORY_NAME"
echo -e "${YELLOW}Image:${NC} $IMAGE_NAME"
echo -e "${YELLOW}Build Image:${NC} $BUILD_IMAGE"
echo ""

# Check if required APIs are enabled
echo -e "${GREEN}Checking required APIs...${NC}"
REQUIRED_APIS=("cloudbuild.googleapis.com" "run.googleapis.com" "artifactregistry.googleapis.com" "aiplatform.googleapis.com")
for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo -e "  ✓ $api is enabled"
    else
        echo -e "${YELLOW}  Enabling $api...${NC}"
        gcloud services enable "$api" --project="$PROJECT_ID"
    fi
done
echo ""

# Create Artifact Registry repository if it doesn't exist
echo -e "${GREEN}Checking Artifact Registry repository...${NC}"
if gcloud artifacts repositories describe "$REPOSITORY_NAME" \
    --location="$REGION" \
    --project="$PROJECT_ID" &>/dev/null; then
    echo -e "  ✓ Repository '$REPOSITORY_NAME' exists"
else
    echo -e "${YELLOW}  Creating repository '$REPOSITORY_NAME'...${NC}"
    gcloud artifacts repositories create "$REPOSITORY_NAME" \
        --repository-format=docker \
        --location="$REGION" \
        --project="$PROJECT_ID" \
        --description="Docker repository for ADK samples"
    echo -e "  ✓ Repository created"
fi
echo ""

# Check if image exists
IMAGE_EXISTS=false
if gcloud artifacts docker images describe "$IMAGE_NAME:latest" \
    --project="$PROJECT_ID" &>/dev/null; then
    IMAGE_EXISTS=true
    echo -e "${GREEN}✓ Image exists in Artifact Registry${NC}"
else
    echo -e "${YELLOW}Image does not exist in Artifact Registry${NC}"
fi
echo ""

# Build the image if requested or if it doesn't exist
if [ "$BUILD_IMAGE" = "true" ] || [ "$IMAGE_EXISTS" = "false" ]; then
    echo -e "${GREEN}Building Docker image with Cloud Build...${NC}"
    gcloud builds submit \
        --tag "$IMAGE_NAME" \
        --project="$PROJECT_ID" \
        --timeout=30m
    
    echo -e "${GREEN}✓ Image built successfully${NC}"
    echo ""
else
    echo -e "${GREEN}Skipping build, using existing image${NC}"
    echo -e "${YELLOW}To force a rebuild, set BUILD_IMAGE=true${NC}"
    echo ""
fi

# Get or create service account for Cloud Run
SERVICE_ACCOUNT_NAME="adk-samples-runner"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${GREEN}Checking service account...${NC}"
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID" &>/dev/null; then
    echo -e "  ✓ Service account '$SERVICE_ACCOUNT_EMAIL' exists"
else
    echo -e "${YELLOW}  Creating service account '$SERVICE_ACCOUNT_NAME'...${NC}"
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="ADK Samples Cloud Run Service Account" \
        --project="$PROJECT_ID"
    echo -e "  ✓ Service account created"
    
    # Wait for service account to propagate across Google Cloud services
    echo -e "${YELLOW}  Waiting for service account to propagate (10 seconds)...${NC}"
    sleep 10
    echo -e "  ✓ Service account propagation complete"
fi

# Grant necessary IAM roles to the service account
echo -e "${GREEN}Granting IAM permissions to service account...${NC}"

# Vertex AI User role - allows calling Vertex AI APIs
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/aiplatform.user" \
    --condition=None \
    --quiet
echo -e "  ✓ Vertex AI User role granted"

# Optional: Grant logging permissions if you want the service to write logs
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/logging.logWriter" \
    --condition=None \
    --quiet
echo -e "  ✓ Logging Writer role granted"

echo -e "${YELLOW}Service Account:${NC} $SERVICE_ACCOUNT_EMAIL"
echo -e "${YELLOW}Permissions granted:${NC}"
echo -e "  - roles/aiplatform.user (Vertex AI access)"
echo -e "  - roles/logging.logWriter (Cloud Logging)"
echo ""

# Deploy to Cloud Run
echo -e "${GREEN}Deploying to Cloud Run...${NC}"
gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_NAME" \
    --platform managed \
    --region "$REGION" \
    --project="$PROJECT_ID" \
    --service-account="$SERVICE_ACCOUNT_EMAIL" \
    --no-allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --max-instances 10 \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID,VERTEX_AI_LOCATION=$REGION"

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""

# Get the service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --platform managed \
    --region "$REGION" \
    --project="$PROJECT_ID" \
    --format="value(status.url)")

echo -e "${GREEN}Service URL:${NC} $SERVICE_URL"
echo ""
echo -e "${YELLOW}Note:${NC} This service requires authentication."
echo ""
echo -e "${YELLOW}To access the service with authentication:${NC}"
echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" $SERVICE_URL"
echo ""
echo -e "${YELLOW}To rebuild the image:${NC}"
echo "  BUILD_IMAGE=true ./deploy.sh"
echo ""
echo -e "${YELLOW}To view logs:${NC}"
echo "  gcloud run services logs read $SERVICE_NAME --region=$REGION --project=$PROJECT_ID"
echo ""
echo -e "${YELLOW}To update environment variables:${NC}"
echo "  gcloud run services update $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --set-env-vars KEY=VALUE"
echo ""
echo -e "${YELLOW}To grant access to specific users/service accounts:${NC}"
echo "  gcloud run services add-iam-policy-binding $SERVICE_NAME \\"
echo "    --region=$REGION \\"
echo "    --member='user:EMAIL@example.com' \\"
echo "    --role='roles/run.invoker'"
echo ""
