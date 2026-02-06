import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuración de directorios de construcción
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Parche crítico para librerías antiguas (Bluetooth)
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as BaseExtension
            
            // Inyectamos el namespace si falta
            if (android.namespace == null) {
                android.namespace = "io.github.edufolly.flutterbluetoothserial"
            }
            
            // Forzamos compatibilidad
            android.compileSdkVersion(36)
        }
    }
}

// Resolución de conflictos de dependencias core
subprojects {
    project.configurations.all {
        resolutionStrategy {
            // Use modern core libraries to satisfy newer plugins (url_launcher, browser, etc.)
            force("androidx.core:core:1.10.1")
            force("androidx.core:core-ktx:1.10.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}