allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

subprojects {
    project.evaluationDependsOn(":app")
}

// 🛡️ THE LIFECYCLE-SAFE COMPILER PATCH
subprojects {
    val configBlock = Action<Project> {
        // Force all subproject Java compiler tasks to JVM 11
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_11.toString()
            targetCompatibility = JavaVersion.VERSION_11.toString()
        }

        // Intercept legacy and modern Kotlin tasks safely by name
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

    if (state.executed) {
        configBlock.execute(this)
    } else {
        afterEvaluate(configBlock)
    }
}

// 🛠️ Added the buildscript block to properly register the Google Services Classpath for legacy structures
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