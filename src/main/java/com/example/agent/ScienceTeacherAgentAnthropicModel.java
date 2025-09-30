package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.LlmAgent;
import com.google.adk.models.springai.SpringAI;
import org.springframework.ai.anthropic.AnthropicChatModel;
import org.springframework.ai.anthropic.api.AnthropicApi;

/** Science teacher agent. */
public class ScienceTeacherAgentAnthropicModel {

    // Field expected by the Dev UI to load the agent dynamically
    // (the agent must be initialized at declaration time)
    public static BaseAgent ROOT_AGENT = initAgent();

    private static final String CLAUDE_MODEL = "claude-sonnet-4-5";

    public static BaseAgent initAgent() {
        AnthropicApi anthropicApi =
            AnthropicApi.builder().apiKey(System.getenv("ANTHROPIC_API_KEY")).build();
        AnthropicChatModel anthropicModel =
            AnthropicChatModel.builder().anthropicApi(anthropicApi).build();

        // Wrap with SpringAI
        SpringAI springAI = new SpringAI(anthropicModel, CLAUDE_MODEL);

        return LlmAgent.builder()
                .name("ScienceAgent-Anthropic-Sonnet4-5-Model")
                .description("A science teacher agent that explains science concepts to kids and teenagers using a real Anthropic API.")
                .model(springAI)
                .instruction("""
                    You are a helpful science teacher that explains
                    science concepts to kids and teenagers.
                    """)
                .build();
    }
}
