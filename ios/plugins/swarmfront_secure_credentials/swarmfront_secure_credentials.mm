#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <TargetConditionals.h>

#include "core/io/json.h"
#include "core/object/class_db.h"
#include "swarmfront_secure_credentials.h"

namespace {

String json_string(const Dictionary &p_value) {
	return JSON::stringify(p_value);
}

String error_json(const char *p_error, OSStatus p_status = errSecSuccess) {
	Dictionary result;
	result["ok"] = false;
	result["err"] = String(p_error);
	if (p_status != errSecSuccess) {
		result["status"] = int64_t(p_status);
	}
	return json_string(result);
}

NSData *key_tag(const String &p_key_alias) {
	CharString utf8 = (String("com.matthew.swarmfront.credentials.") + p_key_alias).utf8();
	return [NSData dataWithBytes:utf8.get_data() length:utf8.length()];
}

NSString *base64url(NSData *p_data) {
	NSString *encoded = [p_data base64EncodedStringWithOptions:0];
	encoded = [encoded stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
	encoded = [encoded stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	return [encoded stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

String godot_string(NSString *p_value) {
	return String::utf8([p_value UTF8String]);
}

SecKeyRef load_private_key(const String &p_key_alias, OSStatus *r_status) {
	NSDictionary *query = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassKey,
		(__bridge id)kSecAttrApplicationTag : key_tag(p_key_alias),
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecReturnRef : @YES
	};
	CFTypeRef item = nullptr;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &item);
	if (r_status != nullptr) {
		*r_status = status;
	}
	return status == errSecSuccess ? (SecKeyRef)item : nullptr;
}

} // namespace

void SwarmfrontSecureCredentials::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &SwarmfrontSecureCredentials::is_available);
	ClassDB::bind_method(D_METHOD("create_device_key", "key_alias"), &SwarmfrontSecureCredentials::create_device_key);
	ClassDB::bind_method(D_METHOD("public_key_jwk", "key_alias"), &SwarmfrontSecureCredentials::public_key_jwk);
	ClassDB::bind_method(D_METHOD("sign_challenge", "key_alias", "challenge_utf8"), &SwarmfrontSecureCredentials::sign_challenge);
	ClassDB::bind_method(D_METHOD("delete_device_key", "key_alias"), &SwarmfrontSecureCredentials::delete_device_key);
}

bool SwarmfrontSecureCredentials::is_available() const {
	return true;
}

String SwarmfrontSecureCredentials::create_device_key(const String &p_key_alias) {
	if (p_key_alias.strip_edges().is_empty()) {
		return error_json("secure_credential_key_alias_invalid");
	}
	OSStatus lookup_status = errSecSuccess;
	SecKeyRef existing = load_private_key(p_key_alias, &lookup_status);
	if (existing != nullptr) {
		CFRelease(existing);
		Dictionary result;
		result["ok"] = true;
		result["created"] = false;
		result["algorithm"] = "ECDSA_P256_SHA256";
		return json_string(result);
	}
	if (lookup_status != errSecItemNotFound) {
		return error_json("secure_credential_key_lookup_failed", lookup_status);
	}

	CFErrorRef access_error = nullptr;
	SecAccessControlRef access = SecAccessControlCreateWithFlags(
			kCFAllocatorDefault,
			kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
			kSecAccessControlPrivateKeyUsage,
			&access_error);
	if (access == nullptr) {
		if (access_error != nullptr) {
			CFRelease(access_error);
		}
		return error_json("secure_credential_access_control_failed");
	}

	NSMutableDictionary *private_attributes = [@{
		(__bridge id)kSecAttrIsPermanent : @YES,
		(__bridge id)kSecAttrApplicationTag : key_tag(p_key_alias),
		(__bridge id)kSecAttrAccessControl : (__bridge id)access
	} mutableCopy];
	NSMutableDictionary *attributes = [@{
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrKeySizeInBits : @256,
		(__bridge id)kSecPrivateKeyAttrs : private_attributes
	} mutableCopy];
#if !TARGET_OS_SIMULATOR
	attributes[(__bridge id)kSecAttrTokenID] = (__bridge id)kSecAttrTokenIDSecureEnclave;
#endif

	CFErrorRef create_error = nullptr;
	SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &create_error);
	CFRelease(access);
	if (key == nullptr) {
		OSStatus status = errSecParam;
		if (create_error != nullptr) {
			status = (OSStatus)CFErrorGetCode(create_error);
			CFRelease(create_error);
		}
		return error_json("secure_credential_key_creation_failed", status);
	}
	CFRelease(key);

	Dictionary result;
	result["ok"] = true;
	result["created"] = true;
	result["algorithm"] = "ECDSA_P256_SHA256";
#if TARGET_OS_SIMULATOR
	result["storage"] = "SIMULATOR_KEYCHAIN";
#else
	result["storage"] = "SECURE_ENCLAVE";
#endif
	return json_string(result);
}

String SwarmfrontSecureCredentials::public_key_jwk(const String &p_key_alias) {
	OSStatus status = errSecSuccess;
	SecKeyRef private_key = load_private_key(p_key_alias, &status);
	if (private_key == nullptr) {
		return error_json("secure_credential_key_not_found", status);
	}
	SecKeyRef public_key = SecKeyCopyPublicKey(private_key);
	CFRelease(private_key);
	if (public_key == nullptr) {
		return error_json("secure_credential_public_key_failed");
	}
	CFErrorRef export_error = nullptr;
	CFDataRef external = SecKeyCopyExternalRepresentation(public_key, &export_error);
	CFRelease(public_key);
	if (external == nullptr) {
		if (export_error != nullptr) {
			CFRelease(export_error);
		}
		return error_json("secure_credential_public_key_export_failed");
	}
	NSData *point = (__bridge NSData *)external;
	if (point.length != 65 || ((const uint8_t *)point.bytes)[0] != 0x04) {
		CFRelease(external);
		return error_json("secure_credential_public_key_format_invalid");
	}
	NSData *x = [point subdataWithRange:NSMakeRange(1, 32)];
	NSData *y = [point subdataWithRange:NSMakeRange(33, 32)];
	Dictionary jwk;
	jwk["kty"] = "EC";
	jwk["crv"] = "P-256";
	jwk["x"] = godot_string(base64url(x));
	jwk["y"] = godot_string(base64url(y));
	CFRelease(external);

	Dictionary result;
	result["ok"] = true;
	result["jwk"] = jwk;
	result["algorithm"] = "ECDSA_P256_SHA256";
	return json_string(result);
}

String SwarmfrontSecureCredentials::sign_challenge(const String &p_key_alias, const String &p_challenge_utf8) {
	if (p_challenge_utf8.is_empty()) {
		return error_json("secure_credential_challenge_invalid");
	}
	OSStatus status = errSecSuccess;
	SecKeyRef private_key = load_private_key(p_key_alias, &status);
	if (private_key == nullptr) {
		return error_json("secure_credential_key_not_found", status);
	}
	CharString challenge = p_challenge_utf8.utf8();
	NSData *data = [NSData dataWithBytes:challenge.get_data() length:challenge.length()];
	CFErrorRef sign_error = nullptr;
	CFDataRef signature = SecKeyCreateSignature(
			private_key,
			kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
			(__bridge CFDataRef)data,
			&sign_error);
	CFRelease(private_key);
	if (signature == nullptr) {
		OSStatus sign_status = errSecParam;
		if (sign_error != nullptr) {
			sign_status = (OSStatus)CFErrorGetCode(sign_error);
			CFRelease(sign_error);
		}
		return error_json("secure_credential_signing_failed", sign_status);
	}
	String encoded = godot_string(base64url((__bridge NSData *)signature));
	CFRelease(signature);

	Dictionary result;
	result["ok"] = true;
	result["signature"] = encoded;
	result["signature_format"] = "X962_DER";
	result["algorithm"] = "ECDSA_P256_SHA256";
	return json_string(result);
}

String SwarmfrontSecureCredentials::delete_device_key(const String &p_key_alias) {
	NSDictionary *query = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassKey,
		(__bridge id)kSecAttrApplicationTag : key_tag(p_key_alias),
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom
	};
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
	if (status != errSecSuccess && status != errSecItemNotFound) {
		return error_json("secure_credential_key_delete_failed", status);
	}
	Dictionary result;
	result["ok"] = true;
	result["deleted"] = status == errSecSuccess;
	return json_string(result);
}
