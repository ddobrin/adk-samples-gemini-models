/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.RunConfig;
import com.google.adk.events.Event;
import com.google.adk.runner.InMemoryRunner;
import com.google.adk.sessions.Session;
import com.google.genai.types.Content;
import com.google.genai.types.Part;
import io.reactivex.rxjava3.core.Flowable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Custom A2A Controller that provides clean responses without tool call traces.
 * 
 * This controller bypasses the default ADK A2A webservice to gain full control
 * over the response format. It processes A2A requests, executes the agent,
 * and returns only the final natural language response without tool traces.
 * 
 * The endpoint is at /a2a/custom/v1/message:send instead of the default
 * /a2a/remote/v1/message:send to avoid conflicts with the ADK webservice.
 */
@RestController
public class CustomA2AController {
    
    private final InMemoryRunner runner;
    private final BaseAgent rootAgent = HelloWeatherAgent.ROOT_AGENT;
    private final String appName = "CustomA2AAgent";
    
    // Regex patterns to remove various types of tool traces
    private static final Pattern MARKDOWN_TABLE_PATTERN = Pattern.compile(
        "\\|[^\\n]*\\|\\s*\\n\\|\\s*[-:]+\\s*\\|[^\\n]*\\n(\\|[^\\n]*\\|\\s*\\n)*",
        Pattern.MULTILINE
    );
    
    private static final Pattern FUNCTION_CALL_PATTERN = Pattern.compile(
        "\\w+\\s*\\([^)]*\\)\\s*[=:]",
        Pattern.MULTILINE
    );
    
    private static final Pattern KEY_VALUE_PATTERN = Pattern.compile(
        "\\.\\w+\\s*[=:]\\s*[^\\n]+",
        Pattern.MULTILINE
    );
    
    public CustomA2AController() {
        this.runner = new InMemoryRunner(rootAgent, appName);
    }
    
    /**
     * Handles A2A message requests with filtered responses.
     * 
     * This endpoint processes A2A protocol messages but filters out tool call
     * traces from the response, returning only the final natural language answer.
     */
    @PostMapping("/a2a/custom/v1/message:send")
    public Map<String, Object> handleMessage(@RequestBody Map<String, Object> request) {
        try {
            // Extract request components
            String jsonrpc = (String) request.get("jsonrpc");
            String requestId = (String) request.get("id");
            String method = (String) request.get("method");
            Map<String, Object> params = (Map<String, Object>) request.get("params");
            
            // Extract message from params
            Map<String, Object> message = (Map<String, Object>) params.get("message");
            String contextId = (String) message.get("contextId");
            String messageId = (String) message.get("messageId");
            List<Map<String, Object>> parts = (List<Map<String, Object>>) message.get("parts");
            
            // Extract user input from parts
            String userInput = extractUserInput(parts);
            
            // Create or get session - ensure we always have a valid contextId
            String sessionId = contextId != null && !contextId.isEmpty() ? contextId : UUID.randomUUID().toString();
            String userId = "user-" + sessionId;
            
            Session session = runner.sessionService()
                .createSession(appName, userId)
                .blockingGet();
            
            // Create user content
            Content userContent = Content.fromParts(Part.fromText(userInput));
            
            // Run the agent
            RunConfig runConfig = RunConfig.builder().build();
            Flowable<Event> events = runner.runAsync(session.userId(), session.id(), userContent, runConfig);
            
            // Collect the final response (only agent's natural language response)
            AtomicReference<String> finalResponse = new AtomicReference<>("");
            events.blockingForEach(event -> {
                // Check for final response
                if (event.finalResponse()) {
                    // Get the string content directly
                    String response = event.stringifyContent();
                    if (response != null && !response.isEmpty()) {
                        // Apply aggressive text cleaning to remove all tool traces
                        String cleanedResponse = cleanTextResponse(response);
                        if (!cleanedResponse.trim().isEmpty()) {
                            finalResponse.set(cleanedResponse);
                        }
                    }
                }
            });
            
            // Build A2A response - use sessionId as contextId to ensure it's never null
            return buildA2AResponse(requestId, sessionId, messageId, finalResponse.get());
            
        } catch (Exception e) {
            // Return error response
            return buildErrorResponse(request.get("id"), e.getMessage());
        }
    }
    
    /**
     * Extracts user input from A2A message parts.
     */
    private String extractUserInput(List<Map<String, Object>> parts) {
        if (parts == null || parts.isEmpty()) {
            return "";
        }
        
        return parts.stream()
            .map(part -> {
                // Handle text parts
                String text = (String) part.get("text");
                if (text != null) {
                    return text;
                }
                // Handle other part types if needed
                return "";
            })
            .filter(text -> !text.isEmpty())
            .collect(Collectors.joining("\n"));
    }
    
    /**
     * Cleans text response by removing tool traces using regex patterns.
     * Removes markdown tables, function calls, and key-value pairs that represent
     * tool execution metadata.
     */
    private String cleanTextResponse(String text) {
        if (text == null || text.trim().isEmpty()) {
            return "";
        }
        
        String cleaned = text;
        
        // Remove markdown tables
        cleaned = MARKDOWN_TABLE_PATTERN.matcher(cleaned).replaceAll("");
        
        // Remove function call patterns
        cleaned = FUNCTION_CALL_PATTERN.matcher(cleaned).replaceAll("");
        
        // Remove key-value patterns (like .args.city = nyc)
        cleaned = KEY_VALUE_PATTERN.matcher(cleaned).replaceAll("");
        
        // Remove multiple consecutive newlines
        cleaned = cleaned.replaceAll("\\n{3,}", "\n\n");
        
        // Trim whitespace
        cleaned = cleaned.trim();
        
        return cleaned;
    }
    
    /**
     * Builds A2A protocol compliant response.
     * 
     * Response structure follows the A2A specification:
     * - jsonrpc: Protocol version
     * - id: Request ID for correlation
     * - result: Message object containing:
     *   - kind: "message" (required)
     *   - messageId: Unique message identifier (required)
     *   - role: "agent" (required)
     *   - contextId: Conversation context identifier (required)
     *   - parts: Array of message parts with kind and content (required)
     */
    private Map<String, Object> buildA2AResponse(String requestId, String contextId, 
                                                  String messageId, String responseText) {
        Map<String, Object> response = new HashMap<>();
        response.put("jsonrpc", "2.0");
        response.put("id", requestId);
        
        // Build result message
        Map<String, Object> result = new HashMap<>();
        result.put("kind", "message");
        result.put("messageId", UUID.randomUUID().toString());
        result.put("role", "agent");
        result.put("contextId", contextId);
        
        // Build parts with only the clean response
        List<Map<String, Object>> parts = new ArrayList<>();
        Map<String, Object> textPart = new HashMap<>();
        textPart.put("kind", "text");
        textPart.put("text", responseText);
        parts.add(textPart);
        
        result.put("parts", parts);
        response.put("result", result);
        
        return response;
    }
    
    /**
     * Builds error response for A2A protocol.
     */
    private Map<String, Object> buildErrorResponse(Object requestId, String errorMessage) {
        Map<String, Object> response = new HashMap<>();
        response.put("jsonrpc", "2.0");
        response.put("id", requestId);
        
        Map<String, Object> error = new HashMap<>();
        error.put("code", -32603);
        error.put("message", "Internal error: " + errorMessage);
        response.put("error", error);
        
        return response;
    }
}
