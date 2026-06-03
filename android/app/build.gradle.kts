import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ تمت إزالة Google Services plugin
}

// تعريف keystoreProperties للعمل المحلي فقط
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "sy.charity_donations.syrian_arab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.3.13750724"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "sy.charity_donations.syrian_arab"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        
        // ✨ تحقق من رقم الإصدار قبل البناء
        val versionNameFromFile = flutter.versionName
        val versionCodeFromFile = flutter.versionCode?.toInt() ?: 1

        println("🔢 Building version: $versionNameFromFile (Code: $versionCodeFromFile)")

        versionCode = versionCodeFromFile
        versionName = versionNameFromFile
        
        multiDexEnabled = true
    }

    // ✨ تم نقل كود إعادة التسمية إلى المكان الصحيح
    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                // استخراج اسم المعمارية (arm64-v8a, armeabi-v7a, etc.)
                val abi = output.outputFile.name.split("-")[1]
                // ✨ تم تحسين اسم الملف ليكون أوضح وأقصر
                val outputFileName = "minex-${abi}.apk"
                output.outputFileName = outputFileName
            }
    }
    
    // ✅ الكود الجديد الذي يعتمد على GitHub Secrets
    signingConfigs {
        create("release") {
            // التحقق مما إذا كنا في بيئة CI/CD (GitHub Actions)
            val isCi = System.getenv("CI") != null

            if (isCi) {
                println("🔑 Running in CI environment. Setting up keystore from GitHub Secrets.")

                // 1. فك تشفير وإنشاء ملف minex.jks مؤقت
                val keystoreBase64 = System.getenv("KEYSTORE_BASE64")
                if (keystoreBase64 == null) {
                    throw GradleException("❌ KEYSTORE_BASE64 secret not found in GitHub Actions.")
                }
                val keystoreFile = file("minex.jks")
                keystoreFile.writeBytes(Base64.getDecoder().decode(keystoreBase64))
                storeFile = keystoreFile

                // 2. قراءة باقي البيانات من الـ Secrets
                keyAlias = System.getenv("KEY_ALIAS") ?: throw GradleException("❌ KEY_ALIAS secret not found.")
                keyPassword = System.getenv("KEY_PASSWORD") ?: throw GradleException("❌ KEY_PASSWORD secret not found.")
                storePassword = System.getenv("STORE_PASSWORD") ?: throw GradleException("❌ STORE_PASSWORD secret not found.")

                println("✅ Keystore created and signing configured successfully from GitHub Secrets.")

            } else {
                // هذا الجزء يعمل فقط على جهازك المحلي
                println("🔑 Running locally. Setting up keystore from key.properties file.")
                keyAlias = keystoreProperties["keyAlias"] as? String
                keyPassword = keystoreProperties["keyPassword"] as? String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as? String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // ✅ تمت إزالة جميع dependencies المتعلقة بـ Firebase
}