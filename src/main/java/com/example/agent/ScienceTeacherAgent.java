package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.LlmAgent;

/** Science teacher agent. */
public class ScienceTeacherAgent {

    // Field expected by the Dev UI to load the agent dynamically
    // (the agent must be initialized at declaration time)
    public static BaseAgent ROOT_AGENT = initAgent();

    public static BaseAgent initAgent() {
        return LlmAgent.builder()
                .name("ScienceAgent-ADK")
                .description("Science teacher agent")
                .model("gemini-2.5-flash")
                .instruction("""
                    You are a helpful science teacher that explains
                    science concepts to kids and teenagers.
                    """)
                .build();
    }
}
