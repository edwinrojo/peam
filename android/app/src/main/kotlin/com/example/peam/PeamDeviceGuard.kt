package com.example.peam

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Device checks that Flutter plugins do not expose: Play Integrity tokens,
 * a Keystore key that Android deletes when a new strong biometric is
 * enrolled, and a monotonic clock that survives changes to the phone time.
 */
object PeamDeviceGuard {
    const val CHANNEL = "peam.device_guard"

    private const val KEYSTORE = "AndroidKeyStore"
    private const val GUARD_ALIAS = "peam_bio_guard"
    private const val CLOUD_PROJECT_NUMBER = 1092448432341L

    fun handle(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "integrityToken" -> integrityToken(context, call, result)
            "bioGuardState" -> result.success(bioGuardState())
            "armBioGuard" -> result.success(armBioGuard())
            "resetBioGuard" -> {
                resetBioGuard()
                result.success(null)
            }
            "clock" -> result.success(clock(context))
            else -> result.notImplemented()
        }
    }

    private fun integrityToken(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val nonce = call.argument<String>("nonce")
        if (nonce.isNullOrEmpty()) {
            result.error("bad_nonce", "A nonce is required.", null)
            return
        }
        try {
            IntegrityManagerFactory.create(context.applicationContext)
                .requestIntegrityToken(
                    IntegrityTokenRequest.builder()
                        .setNonce(nonce)
                        .setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
                        .build(),
                )
                .addOnSuccessListener { response -> result.success(response.token()) }
                .addOnFailureListener { error ->
                    result.error("integrity_unavailable", error.message, null)
                }
        } catch (error: Throwable) {
            result.error("integrity_unavailable", error.message, null)
        }
    }

    /** One of `ok`, `missing`, `changed`, or `unsupported`. */
    private fun bioGuardState(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return "unsupported"
        }
        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            val key = keyStore.getKey(GUARD_ALIAS, null) as? SecretKey ?: return "missing"
            Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.ENCRYPT_MODE, key)
            "ok"
        } catch (_: KeyPermanentlyInvalidatedException) {
            "changed"
        } catch (_: Throwable) {
            "unsupported"
        }
    }

    private fun armBioGuard(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        return try {
            resetBioGuard()
            val builder =
                KeyGenParameterSpec.Builder(
                    GUARD_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setUserAuthenticationRequired(true)
                    .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setUserAuthenticationParameters(
                    0,
                    KeyProperties.AUTH_BIOMETRIC_STRONG,
                )
            }
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).apply {
                init(builder.build())
                generateKey()
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun resetBioGuard() {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            if (keyStore.containsAlias(GUARD_ALIAS)) {
                keyStore.deleteEntry(GUARD_ALIAS)
            }
        } catch (_: Throwable) {
        }
    }

    private fun clock(context: Context): Map<String, Any?> {
        val bootCount =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
                } catch (_: Throwable) {
                    null
                }
            } else {
                null
            }
        return mapOf(
            "elapsedMs" to SystemClock.elapsedRealtime(),
            "bootCount" to bootCount,
        )
    }
}
