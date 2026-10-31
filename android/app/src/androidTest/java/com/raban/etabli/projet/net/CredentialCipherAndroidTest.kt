// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.security.KeyStore
import java.util.Base64
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CredentialCipherAndroidTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val alias = context.packageName + ".credential-test." + UUID.randomUUID()
    private val cipher = CredentialCipher.android(alias)
    private val server = "https://example.test"
    private val legacy = stringPreferencesKey("legacyToken")
    private val encrypted = stringPreferencesKey("encryptedToken")

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @After fun removeTestKey() {
        keyStore().deleteEntry(alias)
    }

    @Test fun tokenSurvivesCipherRecreationWithANonExportableKey() {
        val first = cipher.encrypt("private-token", server)
        val second = cipher.encrypt("private-token", server)
        assertNotEquals(first, second)
        assertNull(keyStore().getKey(alias, null).encoded)
        val reopened = CredentialCipher.android(alias)
        assertEquals("private-token", reopened.decrypt(first, server))
        assertEquals("private-token", reopened.decrypt(second, server))
    }

    @Test fun wrongServerAndModifiedCiphertextAreRejected() {
        val saved = cipher.encrypt("private-token", server)
        assertThrows(IllegalStateException::class.java) {
            cipher.decrypt(saved, "https://another.test")
        }
        val parts = saved.split(':')
        val bytes = Base64.getDecoder().decode(parts[2])
        bytes[0] = (bytes[0].toInt() xor 1).toByte()
        val changed = parts[0] + ":" + parts[1] + ":" + Base64.getEncoder().encodeToString(bytes)
        assertThrows(IllegalStateException::class.java) { cipher.decrypt(changed, server) }
    }

    @Test fun legacyMigrationPersistsAcrossDataStoreReopen() = runBlocking {
        val fixture = StoreFixture(File(context.cacheDir, "credential-test-" + UUID.randomUUID()))
        try {
            fixture.store.edit { it[legacy] = "existing-token" }
            fixture.store.edit {
                assertEquals("existing-token", cipher.readAndMigrate(it, legacy, encrypted, server))
            }
            val migrated = fixture.store.data.first()
            assertNull(migrated[legacy])
            assertNotNull(migrated[encrypted])
            fixture.reopen()
            val reopened = CredentialCipher.android(alias)
            fixture.store.edit {
                assertEquals("existing-token", reopened.readAndMigrate(it, legacy, encrypted, server))
            }
            assertEquals(migrated, fixture.store.data.first())
        } finally {
            fixture.close()
        }
    }

    @Test fun lostKeystoreKeyDoesNotEraseSavedCredentials() = runBlocking {
        val fixture = StoreFixture(File(context.cacheDir, "credential-test-" + UUID.randomUUID()))
        try {
            fixture.store.edit {
                it[legacy] = "existing-token"
                it[encrypted] = cipher.encrypt("existing-token", server)
            }
            val before = fixture.store.data.first()
            keyStore().deleteEntry(alias)
            val failure = runCatching {
                fixture.store.edit { cipher.readAndMigrate(it, legacy, encrypted, server) }
            }.exceptionOrNull()
            assertTrue(failure is IllegalStateException)
            assertEquals("Saved credentials cannot be opened. Reconnect in Settings.", failure?.message)
            fixture.reopen()
            assertEquals(before, fixture.store.data.first())
        } finally {
            fixture.close()
        }
    }

    private class StoreFixture(private val directory: File) {
        private var job = SupervisorJob()
        var store = createStore()
            private set

        private fun createStore() = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(job + Dispatchers.IO),
        ) { File(directory, "credentials.preferences_pb") }

        suspend fun reopen() {
            job.cancelAndJoin()
            job = SupervisorJob()
            store = createStore()
        }

        suspend fun close() {
            job.cancelAndJoin()
            directory.deleteRecursively()
        }
    }
}
