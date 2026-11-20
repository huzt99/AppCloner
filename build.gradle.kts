plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.example.appcloner"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.appcloner"
        minSdk = 24
        targetSdk = 28 // مشاريع الحاويات تحتاج targetSdk قديم، راجع README المكتبة
        versionCode = 1
        versionName = "0.1"
    }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.compose.material:material-icons-extended")
    // TODO: ضع إحداثيات BlackBox الصحيحة من README المشروع (JitPack)
    // implementation("com.github.<owner>:BlackBox:<version>")
}
