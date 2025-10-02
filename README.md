ADK samples with Gemini Models

Set environment variables
```aiexclude
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=... 
export GOOGLE_API_KEY=... 
export GOOGLE_CLOUD_PROJECT=...
export GOOGLE_CLOUD_LOCATION=us-central1
```

In IDE:
```aiexclude
ANTHROPIC_API_KEY=...;OPENAI_API_KEY=...;GOOGLE_API_KEY=...;ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
```

Clone the ADK repo
```aiexclude
git clone https://github.com/ddobrin/adk-java.git
cd adk-java/
./mvnw clean install -DskipTests
```

Clone the samples repo
```aiexclude
git clone https://github.com/ddobrin/adk-samples-gemini-models.git
cd adk-samples-gemini-models/
mvn clean package
```

Run samples
```aiexclude
mvn spring-boot:run -Dspring-boot.run.arguments="--adk.agents.source-dir=<full-path>/adk-samples-gemini-models/"
 
 or 
 
export ADK_AGENTS_SOURCE_DIR=<full-path>/adk-samples-gemini-models/
mvn spring-boot:run
```

Alternatively, uncomment the following line in application.properties and specify the directory
```aiexclude
adk.agents.source-dir=...
```

It starts the AdkWebServer specified in the pom.xml
```xml
...
<build>
  <plugins>
    <plugin>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-maven-plugin</artifactId>
      <version>${spring-boot.version}</version>
      <configuration>
        <mainClass>com.google.adk.web.AdkWebServer</mainClass>
      </configuration>
    </plugin>
  </plugins>
</build>
...
```

