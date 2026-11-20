package com.example.appcloner

/** كل نسخة = userId وهمي من 0 إلى 4. استبدل TODO باستدعاءات BlackBoxCore. */
object CloneManager {
    const val MAX = 5
    private val fake = mutableSetOf<Pair<String, Int>>() // مؤقت حتى ربط BlackBox

    private fun installed(pkg: String, id: Int) = (pkg to id) in fake
        // TODO: BlackBoxCore.get().isInstalled(pkg, id)

    fun clones(pkg: String): List<Int> = (0 until MAX).filter { installed(pkg, it) }

    fun add(pkg: String): Boolean {
        val free = (0 until MAX).firstOrNull { !installed(pkg, it) } ?: return false
        // TODO: return BlackBoxCore.get().installPackageAsUser(free, pkg).success
        return fake.add(pkg to free)
    }

    fun launch(pkg: String, id: Int) {
        // TODO: BlackBoxCore.get().launchApk(pkg, id)
    }

    fun remove(pkg: String, id: Int) {
        // TODO: BlackBoxCore.get().uninstallPackageAsUser(pkg, id)
        fake.remove(pkg to id)
    }
}
