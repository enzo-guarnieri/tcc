./gradlew :connector:clean
./gradlew :connector:shadowJar

java -jar connector/build/libs/basic-connector.jar
