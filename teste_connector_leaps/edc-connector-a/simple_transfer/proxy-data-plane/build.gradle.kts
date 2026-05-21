plugins {
    `java-library`
}

dependencies {
    implementation(libs.edc.data.plane.spi)
    implementation(libs.edc.data.plane.iam)
    implementation(libs.jakarta.rsApi)
    implementation(libs.edc.http)
}
