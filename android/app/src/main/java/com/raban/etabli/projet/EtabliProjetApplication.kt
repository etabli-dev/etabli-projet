// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

package com.raban.etabli.projet

import android.app.Application
import com.raban.etabli.projet.net.OPClient

class EtabliProjetApplication : Application() {
    lateinit var client: OPClient
        private set

    override fun onCreate() {
        super.onCreate()
        client = OPClient(this)
    }
}
