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

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

/**
 * Spring configuration to enable component scanning for agent controllers.
 * 
 * This configuration ensures that Spring Boot discovers and registers
 * controllers in the com.example.agent package, including the AgentCardController
 * which provides the A2A agent discovery endpoint.
 */
@Configuration
@ComponentScan(basePackages = {
    "com.example.agent",
    "com.google.adk.webservice"  // Enable A2A web service endpoints
})
public class AgentConfiguration {
    // Configuration class to enable component scanning for:
    // - Custom agent controllers (com.example.agent)
    // - ADK A2A web service endpoints (com.google.adk.webservice)
    
    /**
     * Provides the root agent for A2A protocol communication.
     * This bean is required by the A2A webservice to handle incoming messages.
     * 
     * We use HelloWeatherAgent.ROOT_AGENT as the default agent for A2A communication.
     */
    @Bean
    public com.google.adk.agents.BaseAgent rootAgent() {
        return HelloWeatherAgent.ROOT_AGENT;
    }
}
