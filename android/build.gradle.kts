allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 将 build 目录改到 C 盘短路径，避免 CMake 在 G 盘上创建目录失败
rootProject.layout.buildDirectory.set(file("C:/b"))
val newBuildDir: Directory = rootProject.layout.buildDirectory.get()

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
