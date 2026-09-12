allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("C:/flutter_build"))

subprojects {
    project.layout.buildDirectory.set(file("C:/flutter_build/${project.name}"))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

buildscript {
    extra.set("kotlin_version", "2.1.0")
}
