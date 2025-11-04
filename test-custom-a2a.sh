#!/bin/bash

# Test script for custom A2A endpoint that filters tool traces

set -e

echo "=== Testing Custom A2A Endpoint ==="
echo ""

# Check if running locally or on Cloud Run
if [ -z "$1" ]; then
    BASE_URL="http://localhost:8080"
    USE_AUTH=false
    echo "Testing locally at: $BASE_URL"
else
    BASE_URL="$1"
    TOKEN=$(gcloud auth print-identity-token)
    USE_AUTH=true
    echo "Testing Cloud Run at: $BASE_URL"
fi

echo ""
echo "1. Testing Agent Card Endpoint"
echo "   GET /.well-known/agent-card.json"
if [ "$USE_AUTH" = true ]; then
    AGENT_CARD=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/.well-known/agent-card.json")
else
    AGENT_CARD=$(curl -s "$BASE_URL/.well-known/agent-card.json")
fi
AGENT_URL=$(echo "$AGENT_CARD" | jq -r '.url')
echo "   Agent Card URL: $AGENT_URL"
echo ""

# Check if using custom endpoint
if echo "$AGENT_URL" | grep -q "/a2a/custom/v1/message:send"; then
    echo "   ✅ Using custom A2A endpoint (tool traces filtered)"
else
    echo "   ⚠️  Using default A2A endpoint (tool traces included)"
fi
echo ""

echo "2. Testing Custom A2A Endpoint"
echo "   POST /a2a/custom/v1/message:send"
echo "   Question: What is the weather in London?"
echo ""

if [ "$USE_AUTH" = true ]; then
    RESPONSE=$(curl -s -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "$BASE_URL/a2a/custom/v1/message:send" \
      -d '{
        "jsonrpc": "2.0",
        "id": "test-1",
        "method": "message/send",
        "params": {
          "message": {
            "messageId": "msg-1",
            "role": "user",
            "parts": [{"text": "What is the weather in London?"}]
          }
        }
      }')
else
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      "$BASE_URL/a2a/custom/v1/message:send" \
      -d '{
        "jsonrpc": "2.0",
        "id": "test-1",
        "method": "message/send",
        "params": {
          "message": {
            "messageId": "msg-1",
            "role": "user",
            "parts": [{"text": "What is the weather in London?"}]
          }
        }
      }')
fi

echo "   Full Response:"
echo "$RESPONSE" | jq .
echo ""

# Extract just the text response
TEXT_RESPONSE=$(echo "$RESPONSE" | jq -r '.result.parts[0].text // "No response"')
echo "   Clean Text Response:"
echo "   $TEXT_RESPONSE"
echo ""

# Check if response contains tool traces
if echo "$TEXT_RESPONSE" | grep -q -E "(\|.*call.*\|)|function_call|tool_call|getWeather\("; then
    echo "   ❌ Tool traces detected in response"
else
    echo "   ✅ Clean response without tool traces"
fi

echo ""
echo "3. Testing Default A2A Endpoint (for comparison)"
echo "   POST /a2a/remote/v1/message:send"
echo "   Question: What is the weather in Tokyo?"
echo ""

if [ "$USE_AUTH" = true ]; then
    DEFAULT_RESPONSE=$(curl -s -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "$BASE_URL/a2a/remote/v1/message:send" \
      -d '{
        "jsonrpc": "2.0",
        "id": "test-2",
        "method": "message/send",
        "params": {
          "message": {
            "messageId": "msg-2",
            "role": "user",
            "parts": [{"text": "What is the weather in Tokyo?"}]
          }
        }
      }' 2>/dev/null || echo '{"error": "Endpoint not available"}')
else
    DEFAULT_RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      "$BASE_URL/a2a/remote/v1/message:send" \
      -d '{
        "jsonrpc": "2.0",
        "id": "test-2",
        "method": "message/send",
        "params": {
          "message": {
            "messageId": "msg-2",
            "role": "user",
            "parts": [{"text": "What is the weather in Tokyo?"}]
          }
        }
      }' 2>/dev/null || echo '{"error": "Endpoint not available"}')
fi

echo "   Response:"
echo "$DEFAULT_RESPONSE" | jq . 2>/dev/null || echo "$DEFAULT_RESPONSE"
echo ""

echo "=== Summary ==="
echo "Custom A2A Endpoint: $BASE_URL/a2a/custom/v1/message:send"
echo "Agent Card URL: $AGENT_URL"
echo ""
echo "The custom endpoint should return clean natural language responses"
echo "without tool call traces, tables, or function execution details."
echo ""
echo "To deploy to Cloud Run:"
echo "  ./deploy.sh --build"
echo ""
echo "To test on Cloud Run:"
echo "  ./test-custom-a2a.sh https://your-service-url"
