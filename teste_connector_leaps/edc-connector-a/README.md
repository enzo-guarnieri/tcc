./gradlew :connector:clean
./gradlew :connector:shadowJar

java -jar connector/build/libs/basic-connector.jar

java -Dedc.fs.config=config.properties -jar connector/build/libs/basic-connector.jar

------ transfer -------

java -Dedc.fs.config=configuracoes/consumer-configuration.properties -jar connector/build/libs/basic-connector.jar

java -Dedc.fs.config=configuracoes/provider-configuration.properties -jar connector/build/libs/basic-connector.jar
