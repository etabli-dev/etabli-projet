package com.raban.etabli.projet.net

import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.datastore.preferences.core.stringPreferencesKey
import org.junit.Assert.*
import org.junit.Test
import javax.crypto.KeyGenerator

class CredentialCipherTest {
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    private val cipher = CredentialCipher { key }
    private val server = "https://example.test"
    private val legacy = stringPreferencesKey("token")
    private val encrypted = stringPreferencesKey("encryptedToken")

    @Test fun tokenRoundTripsWithRandomNonces() {
        val first = cipher.encrypt("private-token", server)
        val second = cipher.encrypt("private-token", server)
        assertNotEquals(first, second)
        assertFalse(first.contains("private-token"))
        assertEquals("private-token", cipher.decrypt(first, server))
        assertEquals("private-token", cipher.decrypt(second, server))
    }

    @Test fun movingCiphertextToAnotherServerIsRefused() {
        assertThrows(IllegalStateException::class.java) {
            cipher.decrypt(cipher.encrypt("private-token", server), "https://another.test")
        }
    }

    @Test fun alteredCiphertextAndMissingKeyAreRefused() {
        val value = cipher.encrypt("private-token", server)
        val parts = value.split(':')
        val changed = parts[2].toCharArray().also { it[0] = if (it[0] == 'A') 'B' else 'A' }
        assertThrows(IllegalStateException::class.java) {
            cipher.decrypt(parts[0] + ":" + parts[1] + ":" + String(changed), server)
        }
        val replacement = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        assertThrows(IllegalStateException::class.java) {
            CredentialCipher { replacement }.decrypt(value, server)
        }
    }

    @Test fun legacyTokenMigratesWithoutChangingItsIdentity() {
        val prefs = mutablePreferencesOf(legacy to "existing-token")
        assertEquals("existing-token", cipher.readAndMigrate(prefs, legacy, encrypted, server))
        assertNull(prefs[legacy])
        assertNotNull(prefs[encrypted])
        val saved = prefs[encrypted]
        assertEquals("existing-token", cipher.readAndMigrate(prefs, legacy, encrypted, server))
        assertEquals(saved, prefs[encrypted])
    }

    @Test fun failedEncryptionPreservesLegacyCredentials() {
        val prefs = mutablePreferencesOf(legacy to "existing-token")
        val unavailable = CredentialCipher { throw IllegalStateException("Keystore unavailable") }
        assertThrows(IllegalStateException::class.java) {
            unavailable.readAndMigrate(prefs, legacy, encrypted, server)
        }
        assertEquals("existing-token", prefs[legacy])
        assertNull(prefs[encrypted])
    }
}
