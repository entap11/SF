package com.swarmfront.securecredentials

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.math.BigInteger
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

class SwarmfrontSecureCredentialsPlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "SwarmfrontSecureCredentials"

    @UsedByGodot
    fun is_available(): Boolean = try {
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        true
    } catch (_: Exception) {
        false
    }

    @UsedByGodot
    fun create_device_key(keyAlias: String): String = guard {
        val alias = platformAlias(keyAlias)
        val keyStore = loadKeyStore()
        if (!keyStore.containsAlias(alias)) {
            val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE_PROVIDER)
            val spec = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(false)
                .build()
            generator.initialize(spec)
            generator.generateKeyPair()
        }
        val jwk = publicJwk(keyStore, alias)
        JSONObject()
            .put("ok", true)
            .put("key_alias", keyAlias)
            .put("algorithm", ALGORITHM)
            .put("jwk", jwk)
    }

    @UsedByGodot
    fun public_key_jwk(keyAlias: String): String = guard {
        JSONObject()
            .put("ok", true)
            .put("jwk", publicJwk(loadKeyStore(), platformAlias(keyAlias)))
    }

    @UsedByGodot
    fun sign_challenge(keyAlias: String, challengeUtf8: String): String = guard {
        require(challengeUtf8.isNotEmpty()) { "invalid_challenge" }
        val entry = loadKeyStore().getEntry(platformAlias(keyAlias), null)
            as? KeyStore.PrivateKeyEntry ?: throw IllegalArgumentException("device_key_not_found")
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(entry.privateKey)
        signer.update(challengeUtf8.toByteArray(StandardCharsets.UTF_8))
        JSONObject()
            .put("ok", true)
            .put("algorithm", ALGORITHM)
            .put("signature", base64Url(signer.sign()))
    }

    @UsedByGodot
    fun delete_device_key(keyAlias: String): String = guard {
        val keyStore = loadKeyStore()
        val alias = platformAlias(keyAlias)
        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        JSONObject().put("ok", true)
    }

    private fun loadKeyStore(): KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    private fun publicJwk(keyStore: KeyStore, alias: String): JSONObject {
        val certificate = keyStore.getCertificate(alias)
            ?: throw IllegalArgumentException("device_key_not_found")
        val publicKey = KeyFactory.getInstance(KeyProperties.KEY_ALGORITHM_EC)
            .generatePublic(java.security.spec.X509EncodedKeySpec(certificate.publicKey.encoded)) as ECPublicKey
        return JSONObject()
            .put("kty", "EC")
            .put("crv", "P-256")
            .put("x", base64Url(unsignedCoordinate(publicKey.w.affineX)))
            .put("y", base64Url(unsignedCoordinate(publicKey.w.affineY)))
            .put("alg", "ES256")
            .put("use", "sig")
    }

    private fun platformAlias(keyAlias: String): String {
        require(keyAlias.isNotBlank() && keyAlias.length <= 128) { "invalid_key_alias" }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(keyAlias.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return "swarmfront.entap.$digest"
    }

    private fun unsignedCoordinate(value: BigInteger): ByteArray {
        val encoded = value.toByteArray()
        val start = if (encoded.size > COORDINATE_BYTES && encoded[0] == 0.toByte()) 1 else 0
        require(encoded.size - start <= COORDINATE_BYTES) { "invalid_public_key" }
        return ByteArray(COORDINATE_BYTES).also { output ->
            encoded.copyInto(output, COORDINATE_BYTES - (encoded.size - start), start)
        }
    }

    private fun base64Url(value: ByteArray): String =
        Base64.encodeToString(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private inline fun guard(block: () -> JSONObject): String = try {
        block().toString()
    } catch (error: Exception) {
        val safeCode = when (error.message) {
            "invalid_key_alias", "invalid_challenge", "device_key_not_found", "invalid_public_key" -> error.message
            else -> "secure_credential_operation_failed"
        }
        JSONObject().put("ok", false).put("err", safeCode).toString()
    }

    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val ALGORITHM = "ECDSA_P256_SHA256"
        private const val COORDINATE_BYTES = 32
    }
}
