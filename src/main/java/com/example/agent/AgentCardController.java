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

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Controller that serves the agent card for A2A protocol discovery.
 * 
 * The agent card is served at /.well-known/agent-card.json and provides
 * metadata about the agent and its capabilities according to the A2A specification.
 * 
 * This implementation follows the official Google Cloud documentation:
 * https://docs.cloud.google.com/gemini/enterprise/docs/register-and-manage-an-a2a-agent
 * 
 * Note: This serves a single agent. To register multiple agents, create separate
 * endpoints or deploy separate services for each agent.
 */
@RestController
public class AgentCardController {
    
    @Value("${agent.base.url:http://localhost:8080}")
    private String agentBaseUrl;
    
    @Value("${agent.name:ADK Multi-Agent Service}")
    private String agentName;
    
    @Value("${agent.description:Multi-agent service with weather, time, and science capabilities}")
    private String agentDescription;
    
    @Value("${agent.version:1.0.0}")
    private String agentVersion;
    
    /**
     * Serves the agent card at the well-known location for A2A discovery.
     * 
     * This endpoint returns an A2A-compliant agent card following the official specification.
     * The agent card describes a unified multi-capability agent that can handle weather,
     * time, and science-related queries.
     * 
     * @return Agent card JSON with metadata conforming to A2A specification
     */
    @GetMapping(value = "/.well-known/agent-card.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> getAgentCard() {
        Map<String, Object> agentCard = new HashMap<>();
        
        // Required: Protocol version (use "v" prefix as per documentation)
        agentCard.put("protocolVersion", "v1.0");
        
        // Required: Basic agent information
        agentCard.put("name", agentName);
        agentCard.put("description", agentDescription);
        agentCard.put("version", agentVersion);
        
        // Required: Base URL where the agent can be reached
        // Using custom A2A endpoint that filters out tool traces
        // The custom endpoint provides clean responses without tool call metadata
        agentCard.put("url", agentBaseUrl + "/a2a/custom/v1/message:send");
        
        // Optional: Icon URL (base64-encoded SVG or image URL)
        // agentCard.put("iconUrl", "data:image/svg+xml;base64,...");
        
        // Required: Protocol-level capabilities (streaming, pushNotifications)
        Map<String, Boolean> capabilities = new HashMap<>();
        capabilities.put("streaming", false);
        capabilities.put("pushNotifications", false);
        agentCard.put("capabilities", capabilities);
        
        // Required: Default input/output MIME types
        agentCard.put("defaultInputModes", List.of("text/plain"));
        agentCard.put("defaultOutputModes", List.of("text/plain"));
        
        // Required: Skills array describing what the agent can do
        agentCard.put("skills", List.of(
            createSkill(
                "weather-query",
                "Weather Information",
                "Retrieves current weather conditions and forecasts for cities worldwide",
                List.of("weather", "forecast", "temperature", "conditions"),
                List.of(
                    "What is the weather in London?",
                    "Forecast for Sydney",
                    "Is it raining in Tokyo?",
                    "Temperature in New York"
                )
            ),
            createSkill(
                "time-query",
                "Time Information",
                "Provides current time and date information for different locations",
                List.of("time", "date", "timezone", "clock"),
                List.of(
                    "What time is it?",
                    "Current time in Paris",
                    "What's the date today?"
                )
            ),
            createSkill(
                "science-education",
                "Science Teaching",
                "Answers science-related questions and provides educational explanations",
                List.of("science", "education", "teaching", "learning"),
                List.of(
                    "Explain photosynthesis",
                    "What is gravity?",
                    "How does the water cycle work?"
                )
            )
        ));
        
        return agentCard;
    }
    
    
    /**
     * Helper method to create a skill object conforming to A2A AgentSkill specification.
     * 
     * @param id Unique skill identifier
     * @param name Human-readable skill name
     * @param description Detailed description of what the skill does
     * @param tags Array of relevant tags for categorization
     * @param examples Array of example queries that demonstrate the skill
     * @return Skill object as a Map
     */
    private Map<String, Object> createSkill(String id, String name, String description, 
                                            List<String> tags, List<String> examples) {
        Map<String, Object> skill = new HashMap<>();
        skill.put("id", id);
        skill.put("name", name);
        skill.put("description", description);
        skill.put("tags", tags);
        skill.put("examples", examples);
        return skill;
    }
}
