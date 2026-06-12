allprojects {
    repositories {
        google()
        mavenCentral()
    }
    extra.set("compileSdkVersion", 36)
    extra.set("targetSdkVersion", 36)
    extra.set("minSdkVersion", 21)
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure proper build ordering safely
subprojects {
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

// 🛡️ COMBINED & LIFECYCLE-SAFE OVERRIDE FOR ALL SUBPROJECTS
subprojects {
    val configBlock = Action<Project> {
        // 1. Force SDK compiling limits cleanly
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val androidExt = extensions.findByType<com.android.build.gradle.BaseExtension>()
            androidExt?.compileSdkVersion(36)
        }

        // 2. Force Java compiler tasks to JVM 11
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_11.toString()
            targetCompatibility = JavaVersion.VERSION_11.toString()
        }

        // 3. Intercept legacy and modern Kotlin tasks safely by name
        tasks.configureEach {
            if (name.contains("KotlinCompile")) {
                try {
                    setProperty("kotlinOptions.jvmTarget", "11")
                } catch (e: Exception) {
                    try {
                        val opts = property("kotlinOptions")
                        opts?.javaClass?.getMethod("setJvmTarget", String::class.java)?.invoke(opts, "11")
                    } catch (err: Exception) {}
                }
            }
        }
    }

    // Dynamic execution guard to stop the "already evaluated" crash
    if (state.executed) {
        configBlock.execute(this)
    } else {
        afterEvaluate(configBlock)
    }
}

// 🛠️ Google Services Classpath registration for Firebase native injection
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}