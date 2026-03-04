package com.example.agent.config;

import com.google.genai.types.Content;
import com.google.genai.types.Part;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;
import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonParser;
import tools.jackson.core.TreeNode;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.JacksonModule;
import tools.jackson.databind.deser.std.StdDeserializer;
import tools.jackson.databind.module.SimpleModule;

/**
 * Bridges Jackson 3.x (Spring Boot 4.x) with the google-genai library's Jackson 2.x types.
 *
 * The google-genai library's Content and Part are abstract classes with Jackson 2.x annotations.
 * Jackson 3.x cannot deserialize them directly because it uses a different package hierarchy.
 * This config registers Jackson 3.x deserializers that delegate to the library's own
 * fromJson() factory methods, which use the library's internal Jackson 2.x ObjectMapper.
 */
@AutoConfiguration
public class JacksonConfig {

    @Bean
    public JacksonModule genaiTypesModule() {
        SimpleModule module = new SimpleModule("GenaiTypesModule");
        module.addDeserializer(Content.class, new ContentDeserializer());
        module.addDeserializer(Part.class, new PartDeserializer());
        return module;
    }

    static class ContentDeserializer extends StdDeserializer<Content> {
        ContentDeserializer() {
            super(Content.class);
        }

        @Override
        public Content deserialize(JsonParser p, DeserializationContext ctxt) throws JacksonException {
            TreeNode node = p.readValueAsTree();
            return Content.fromJson(node.toString());
        }
    }

    static class PartDeserializer extends StdDeserializer<Part> {
        PartDeserializer() {
            super(Part.class);
        }

        @Override
        public Part deserialize(JsonParser p, DeserializationContext ctxt) throws JacksonException {
            TreeNode node = p.readValueAsTree();
            return Part.fromJson(node.toString());
        }
    }
}
