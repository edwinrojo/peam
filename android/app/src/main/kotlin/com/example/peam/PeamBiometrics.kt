package com.example.peam

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android cannot name face vs fingerprint through Flutter's local_auth plugin.
 * Probe hardware (and Samsung face enrollment when present) and open
 * BiometricPrompt with strong-only for fingerprint so Class 2 face is not listed.
 */
object PeamBiometrics {
    const val CHANNEL = "peam.biometrics"

    fun handle(
        activity: FragmentActivity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "probe" -> result.success(probe(activity))
            "authenticate" -> authenticate(activity, call, result)
            else -> result.notImplemented()
        }
    }

    fun probe(context: Context): Map<String, Any?> {
        val packageManager = context.packageManager
        val samsungFace = samsungFaceHardware(context)
        val faceHardware =
            packageManager.hasSystemFeature(PackageManager.FEATURE_FACE) ||
                samsungFace == true ||
                (isSamsung() &&
                    samsungFace != false &&
                    packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT))
        val fingerprintHardware =
            packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)

        return mapOf(
            "faceHardware" to faceHardware,
            "fingerprintHardware" to fingerprintHardware,
            "faceEnrolled" to samsungFaceEnrolled(context),
            "fingerprintEnrolled" to fingerprintEnrolled(context),
        )
    }

    private fun authenticate(
        activity: FragmentActivity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val method = call.argument<String>("method") ?: "fingerprint"
        val title = call.argument<String>("title") ?: "Authentication required"
        val subtitle = call.argument<String>("subtitle") ?: "Verify identity"
        val reason = call.argument<String>("reason") ?: "Authenticate to continue"
        val cancel = call.argument<String>("cancel") ?: "Cancel"

        val authenticators =
            if (method == "fingerprint") {
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            } else {
                BiometricManager.Authenticators.BIOMETRIC_WEAK
            }

        val promptInfo =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(title)
                .setSubtitle(subtitle)
                .setDescription(reason)
                .setNegativeButtonText(cancel)
                .setAllowedAuthenticators(authenticators)
                .setConfirmationRequired(method != "face")
                .build()

        var replied = false
        fun reply(value: Map<String, Any?>) {
            if (replied) {
                return
            }
            replied = true
            result.success(value)
        }

        try {
            val prompt =
                BiometricPrompt(
                    activity,
                    ContextCompat.getMainExecutor(activity),
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(
                            authResult: BiometricPrompt.AuthenticationResult,
                        ) {
                            reply(mapOf("authenticated" to true))
                        }

                        override fun onAuthenticationError(
                            errorCode: Int,
                            errString: CharSequence,
                        ) {
                            reply(
                                mapOf(
                                    "authenticated" to false,
                                    "code" to codeFor(errorCode),
                                    "message" to errString.toString(),
                                ),
                            )
                        }

                        override fun onAuthenticationFailed() {
                            // Incremental failure; wait for success or a terminal error.
                        }
                    },
                )
            prompt.authenticate(promptInfo)
        } catch (error: Throwable) {
            reply(
                mapOf(
                    "authenticated" to false,
                    "code" to "unknownError",
                    "message" to (error.message ?: "Biometric verification failed."),
                ),
            )
        }
    }

    private fun isSamsung(): Boolean {
        return Build.MANUFACTURER.equals("samsung", ignoreCase = true)
    }

    private fun codeFor(errorCode: Int): String =
        when (errorCode) {
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            -> "userCanceled"
            BiometricPrompt.ERROR_CANCELED -> "systemCanceled"
            BiometricPrompt.ERROR_TIMEOUT -> "timeout"
            BiometricPrompt.ERROR_NO_BIOMETRICS -> "noBiometricsEnrolled"
            BiometricPrompt.ERROR_HW_NOT_PRESENT -> "noBiometricHardware"
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "noCredentialsSet"
            BiometricPrompt.ERROR_LOCKOUT -> "temporaryLockout"
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "biometricLockout"
            BiometricPrompt.ERROR_HW_UNAVAILABLE -> "hardwareUnavailable"
            else -> "unknownError"
        }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun fingerprintEnrolled(context: Context): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null
        }
        return try {
            val manager = context.getSystemService(FingerprintManager::class.java)
            manager?.hasEnrolledFingerprints()
        } catch (_: Throwable) {
            null
        }
    }

    private fun samsungFaceHardware(context: Context): Boolean? {
        return invokeSamsungFaceBoolean(context, "isHardwareDetected")
    }

    private fun samsungFaceEnrolled(context: Context): Boolean? {
        return invokeSamsungFaceBoolean(context, "hasEnrolledFaces")
    }

    private fun invokeSamsungFaceBoolean(
        context: Context,
        methodName: String,
    ): Boolean? {
        return try {
            val clazz = Class.forName("com.samsung.android.bio.face.SemBioFaceManager")
            val instance =
                clazz.getMethod("getInstance", Context::class.java).invoke(null, context)
                    ?: return null
            clazz.getMethod(methodName).invoke(instance) as? Boolean
        } catch (_: Throwable) {
            null
        }
    }
}
