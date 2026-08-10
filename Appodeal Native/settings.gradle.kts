pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()


    }
}


dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://plugins.gradle.org/m2/")
        maven("https://central.sonatype.com/repository/maven-snapshots/")

        maven {
            url = uri("https://artifactory.appodeal.com/appodeal")
        }

        maven {
            url = uri("https://artifactory.appodeal.com/appodeal-public")
        }
    }
}

// TODO: Update project's name.
rootProject.name = "AppodealNative"
include(":plugin")
