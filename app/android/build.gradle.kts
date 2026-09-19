allprojects {
    repositories {
        google()
        mavenCentral()

        // flutter_background_geolocation does not publish its native library to
        // any public repository. It ships `tslocationmanager` as AARs inside the
        // plugin, in a local Maven layout, and declares that folder with a
        // *relative* path -- which Gradle resolves against the root project
        // rather than the plugin, so the repository silently points nowhere.
        // Gradle then falls back to the public repositories, where only 4.x
        // exists, and fails to resolve the 3.+ the plugin asks for.
        //
        // Pointing at the plugin's own directory is the fix the plugin's install
        // guide prescribes. Without it the Android app does not build at all.
        findProject(":flutter_background_geolocation")?.let { plugin ->
            maven { url = uri("${plugin.projectDir}/libs") }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
