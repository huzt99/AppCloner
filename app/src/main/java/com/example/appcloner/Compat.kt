package com.example.appcloner

enum class Compat { OK, RISKY, BLOCKED }

object CompatChecker {
    private val blockedHints = listOf("bank", "wallet", "pay", "stcpay", "mada")
    private val riskyPackages = setOf("com.tencent.ig", "com.activision.callofduty.shooter", "com.dts.freefireth")

    fun check(pkg: String): Compat = when {
        blockedHints.any { pkg.contains(it, ignoreCase = true) } -> Compat.BLOCKED
        pkg in riskyPackages -> Compat.RISKY
        else -> Compat.OK
    }
}
