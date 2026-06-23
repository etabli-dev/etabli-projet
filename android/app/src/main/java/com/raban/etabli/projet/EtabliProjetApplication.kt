// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

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
