package com.example.appcloner

import android.app.Application
import android.content.Context

class App : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // TODO BlackBox: BlackBoxCore.get().doAttachBaseContext(base, ClientConfiguration())
    }
    override fun onCreate() {
        super.onCreate()
        // TODO BlackBox: BlackBoxCore.get().doCreate()
    }
}
