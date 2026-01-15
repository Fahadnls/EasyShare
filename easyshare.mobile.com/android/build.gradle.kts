import com.android.build.gradle.BaseExtension

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
    layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        // Apply only to Android modules (app/library)
        extensions.findByType(BaseExtension::class.java)?.let { androidExt ->
            // Some older plugins don't define namespace (AGP 8+ requires it)
            if (androidExt.namespace == null) {
                // Use project.group if set, otherwise fallback to a stable value
                val fallback = (project.group?.toString()?.takeIf { it.isNotBlank() } ?: "com.example")
                androidExt.namespace = fallback
            }
        }
    }
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
