// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Encrypt tokens with an app-specific, non-exportable Android Keystore key. */
class CredentialCipher(private val key: () -> SecretKey) {
    fun encrypt(token: String, server: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(server.toByteArray(Charsets.UTF_8))
        val ciphertext = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        val encoder = Base64.getEncoder()
        return "1:" + encoder.encodeToString(cipher.iv) + ":" + encoder.encodeToString(ciphertext)
    }

    fun decrypt(envelope: String, server: String): String {
        try {
            val parts = envelope.split(':')
            require(parts.size == 3 && parts[0] == "1") { "Unknown credential format" }
            val decoder = Base64.getDecoder()
            val iv = decoder.decode(parts[1])
            require(iv.size == 12) { "Invalid credential nonce" }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
            cipher.updateAAD(server.toByteArray(Charsets.UTF_8))
            return String(cipher.doFinal(decoder.decode(parts[2])), Charsets.UTF_8)
        } catch (error: Exception) {
            throw IllegalStateException("Saved credentials cannot be opened. Reconnect in Settings.", error)
        }
    }

    /**
     * Call inside DataStore.edit: encrypt and remove the old value in one durable update.
     * A failed encryption/decryption leaves the existing preferences untouched.
     */
    fun readAndMigrate(
        preferences: MutablePreferences,
        legacyKey: Preferences.Key<String>,
        encryptedKey: Preferences.Key<String>,
        server: String,
    ): String {
        val encrypted = preferences[encryptedKey]
        if (encrypted != null) {
            val token = decrypt(encrypted, server)
            preferences.remove(legacyKey)
            return token
        }
        val token = preferences[legacyKey].orEmpty()
        if (token.isNotEmpty()) {
            preferences[encryptedKey] = encrypt(token, server)
            preferences.remove(legacyKey)
        }
        return token
    }

    companion object {
        fun android(alias: String): CredentialCipher = CredentialCipher {
            synchronized(CredentialCipher::class.java) {
                val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                (store.getKey(alias, null) as? SecretKey) ?: KeyGenerator
                    .getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
                    .apply {
                        init(KeyGenParameterSpec.Builder(
                            alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                        ).setKeySize(256)
                            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                            .build())
                    }.generateKey()
            }
        }
    }
}
