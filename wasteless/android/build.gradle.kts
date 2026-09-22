allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_local_notifications 12.0.4 predates the namespace requirement in
// current Android Gradle Plugin versions. Configure its published manifest
// package as the namespace without modifying the cached dependency.
subprojects {
    val legacyPluginNamespaces = mapOf(
        "flutter_local_notifications" to "com.dexterous.flutterlocalnotifications",
        "flutter_native_timezone" to "com.whelksoft.flutter_native_timezone",
    )
    legacyPluginNamespaces[name]?.let { pluginNamespace ->
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                namespace = pluginNamespace
            }
        }
    }
}

// flutter_native_timezone 2.0.0 requests Kotlin 1.3.50, which is not
// supported by Android Gradle Plugin 8.7. Use the project's Kotlin toolchain.
subprojects {
    if (name == "flutter_native_timezone") {
        buildscript.configurations.configureEach {
            resolutionStrategy.force("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
