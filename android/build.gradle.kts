allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun forceCompileSdkVersion(androidExtension: Any, sdk: Int) {
    val methods = androidExtension.javaClass.methods

    val setCompileSdk = methods.firstOrNull {
        it.name == "setCompileSdk" && it.parameterCount == 1
    }
    if (setCompileSdk != null) {
        setCompileSdk.invoke(androidExtension, sdk)
        return
    }

    val setCompileSdkVersion = methods.firstOrNull {
        it.name == "setCompileSdkVersion" && it.parameterCount == 1
    }
    if (setCompileSdkVersion != null) {
        val parameterType = setCompileSdkVersion.parameterTypes.first()
        if (parameterType == Int::class.java || parameterType == Int::class.javaPrimitiveType) {
            setCompileSdkVersion.invoke(androidExtension, sdk)
        } else {
            setCompileSdkVersion.invoke(androidExtension, sdk.toString())
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            forceCompileSdkVersion(androidExtension, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
