rootProject.name = "edc-connector-a"


pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        mavenLocal()
    }
}

include(
    ":connector",
    ":federate_catalog:embedded:federated-catalog-base",
    ":federate_catalog:embedded:fixed-node-resolver"
)