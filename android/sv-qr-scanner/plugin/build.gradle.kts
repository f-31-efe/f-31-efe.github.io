import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// Eklenti adı — Godot manifest meta-verisiyle (org.godotengine.plugin.v2.SvQrScanner) eşleşmelidir.
val pluginName = "sv_qr_scanner"
val pluginPackageName = "com.silviagames.qrscanner"
val godotPluginName = "SvQrScanner"

android {
    namespace = pluginPackageName
    compileSdk = 36

    defaultConfig {
        minSdk = 24

        manifestPlaceholders["godotPluginName"] = godotPluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        // Çıktı: plugin/build/outputs/aar/sv_qr_scanner-{debug,release}.aar
        setProperty("archivesBaseName", pluginName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

dependencies {
    // Godot Android kütüphanesi (GodotPlugin + @UsedByGodot)
    implementation("org.godotengine:godot:4.7.2.stable")

    // Kamera önizleme ve yaşam döngüsü
    // Not: Derleme sınıf yolu için 1.6.2 (ListenableFuture erişimi); uygulama
    // çalışma zamanı export_plugin.gd içinde 1.5.3 ile çözelir (AGP 8.6.1 uyumu).
    // Kullanılan CameraX API'leri 1.0'dan beri aynıdır.
    implementation("androidx.camera:camera-camera2:1.6.2")
    implementation("androidx.camera:camera-lifecycle:1.6.2")
    implementation("androidx.camera:camera-view:1.6.2")

    // Barkod çözümleme (cihaz üzerinde, çevrimdışı ML Kit modeli)
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // FileProvider (PNG/CSV paylaşımı) + ComponentActivity (LifecycleOwner)
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.activity:activity:1.9.3")

    // AdMob reklamları
    implementation("com.google.android.gms:play-services-ads:25.5.0")
}
