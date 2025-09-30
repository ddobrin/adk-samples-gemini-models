package com.example.agent;

import com.google.adk.agents.BaseAgent;
import com.google.adk.agents.LlmAgent;
import com.google.adk.events.Event;
import com.google.adk.models.springai.SpringAI;
import com.google.adk.runner.InMemoryRunner;
import com.google.adk.sessions.Session;
import com.google.adk.tools.Annotations;
import com.google.adk.tools.Annotations.Schema;
import com.google.adk.tools.FunctionTool;
import com.google.genai.types.Content;
import com.google.genai.types.Part;
import io.reactivex.rxjava3.core.Flowable;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.Scanner;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.api.OpenAiApi;

public class MultiToolAgentOpenAIModel {

    private static String USER_ID = "student";
    private static String NAME = "MultiToolAgent-OpenAIModel";
    private static final String APP_NAME = "MultiToolAgent-OpenAIModel";
    private static final String MODEL_NAME = "gpt-4o-mini";

    // The run your agent with Dev UI, the ROOT_AGENT should be a global public static variable.
    public static BaseAgent ROOT_AGENT = initAgent();

    public static BaseAgent initAgent() {
        OpenAiApi openAIApi = OpenAiApi.builder().apiKey(System.getenv("OPENAI_API_KEY")).build();
        OpenAiChatModel openAiModel =
            OpenAiChatModel.builder().openAiApi(openAIApi).build();

        // Wrap with SpringAI
        SpringAI springAI = new SpringAI(openAiModel, MODEL_NAME);

        return LlmAgent.builder()
                .name(NAME)
                .model(springAI)
                .description("Agent to answer questions about the time and weather in a city.")
                .instruction(
                        "You are a helpful agent who can answer user questions about the time and weather"
                                + " in a city.")
                .tools(
                        FunctionTool.create(MultiToolAgentOpenAIModel.class, "getCurrentTime"),
                        FunctionTool.create(MultiToolAgentOpenAIModel.class, "getWeather"))
                .build();
    }

    @Schema(description = "Function to get the current time for a given city")
    public static Map<String, String> getCurrentTime(
            @Schema(name = "city", description = "The name of the city for which to retrieve the current time")
            String city) {
        String normalizedCity =
                Normalizer.normalize(city, Normalizer.Form.NFD)
                        .trim()
                        .toLowerCase()
                        .replaceAll("(\\p{IsM}+|\\p{IsP}+)", "")
                        .replaceAll("\\s+", "_");

        return ZoneId.getAvailableZoneIds().stream()
                .filter(zid -> zid.toLowerCase().endsWith("/" + normalizedCity))
                .findFirst()
                .map(
                        zid ->
                                Map.of(
                                        "status",
                                        "success",
                                        "report",
                                        "The current time in "
                                                + city
                                                + " is "
                                                + ZonedDateTime.now(ZoneId.of(zid))
                                                .format(DateTimeFormatter.ofPattern("HH:mm"))
                                                + "."))
                .orElse(
                        Map.of(
                                "status",
                                "error",
                                "report",
                                "Sorry, I don't have timezone information for " + city + "."));
    }

    @Schema(description = "Function to get the weather forecast for a given city")
    public static Map<String, String> getWeather(
            @Schema(name = "city", description = "The name of the city for which to retrieve the weather report")
            String city) {
        if (city.toLowerCase().equals("toronto")) {
            return Map.of(
                    "status",
                    "success",
                    "report",
                    "The weather in Toronto is sunny with a temperature of 25 degrees Celsius (77 degrees"
                            + " Fahrenheit).");

        } else {
            return Map.of(
                    "status", "error", "report", "Weather information for " + city + " is not available.");
        }
    }

    public static void main(String[] args) throws Exception {
        InMemoryRunner runner = new InMemoryRunner(ROOT_AGENT, APP_NAME);

        Session session =
                runner
                        .sessionService()
                        .createSession(NAME, USER_ID)
                        .blockingGet();

        try (Scanner scanner = new Scanner(System.in, StandardCharsets.UTF_8)) {
            while (true) {
                System.out.print("\nYou > ");
                String userInput = scanner.nextLine();

                if ("quit".equalsIgnoreCase(userInput)) {
                    break;
                }

                Content userMsg = Content.fromParts(Part.fromText(userInput));
                Flowable<Event> events = runner.runAsync(USER_ID, session.id(), userMsg);

                System.out.print("\nAgent > ");
                events.blockingForEach(event -> System.out.println(event.stringifyContent()));
            }
        }
    }
}