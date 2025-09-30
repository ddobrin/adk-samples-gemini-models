package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.LlmAgent;
import com.google.adk.models.springai.SpringAI;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.api.OpenAiApi;

/** Science teacher agent. */
public class ScienceTeacherAgentOpenAIModel {

    // Field expected by the Dev UI to load the agent dynamically
    // (the agent must be initialized at declaration time)
    public static BaseAgent ROOT_AGENT = initAgent();

    private static final String  GPT_MODEL = "gpt-41-mini";

    public static BaseAgent initAgent() {
        OpenAiApi openAIApi = OpenAiApi.builder().apiKey(System.getenv("OPENAI_API_KEY")).build();
        OpenAiChatModel openAiModel =
            OpenAiChatModel.builder().openAiApi(openAIApi).build();

        // Wrap with SpringAI
        SpringAI springAI = new SpringAI(openAiModel, GPT_MODEL);

        return LlmAgent.builder()
                .name("ScienceAgent-OpenAI-gpt-41-mini-Model")
                .description("A science teacher agent that explains science concepts to kids and teenagers using a real OpenAI API")
                .model(springAI)
                .instruction("""
                    You are a helpful science teacher that explains
                    science concepts to kids and teenagers.
                    """)
                .build();
    }
}
