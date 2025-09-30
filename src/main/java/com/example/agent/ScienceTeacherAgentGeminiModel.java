package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.LlmAgent;
import com.google.adk.models.springai.SpringAI;
import com.google.genai.Client;
import org.springframework.ai.google.genai.GoogleGenAiChatModel;
import org.springframework.ai.google.genai.GoogleGenAiChatOptions;

/** Science teacher agent. */
public class ScienceTeacherAgentGeminiModel {

    // Field expected by the Dev UI to load the agent dynamically
    // (the agent must be initialized at declaration time)
    public static BaseAgent ROOT_AGENT = initAgent();

    private static final String GEMINI_MODEL = "gemini-2.5-flash";

    public static BaseAgent initAgent() {
      // Create Google GenAI client using API key (not Vertex AI)
      Client genAiClient =
          Client.builder().apiKey(System.getenv("GOOGLE_API_KEY")).vertexAI(false).build();

      GoogleGenAiChatOptions options = GoogleGenAiChatOptions.builder().model(GEMINI_MODEL).build();

      GoogleGenAiChatModel geminiModel =
          GoogleGenAiChatModel.builder().genAiClient(genAiClient).defaultOptions(options).build();

      SpringAI springAI = new SpringAI(geminiModel, GEMINI_MODEL);

      // Create agent
      return LlmAgent.builder()
              .name("ScienceAgent-Gemini-Flash-2-5-Model")
              .description("A science teacher agent that explains science concepts to kids and teenagers using a real Gemini API")
              .model(springAI)
              .instruction("""
                    You are a helpful science teacher that explains
                    science concepts to kids and teenagers.
                    """)
              .build();
    }
}
