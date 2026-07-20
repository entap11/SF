#include "swarmfront_secure_credentials.h"

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <TargetConditionals.h>

namespace {

static const char *ALGORITHM = "ECDSA_P256_SHA256";

static NSString *to_ns_string(const String &p_value) {
	return [NSString stringWithUTF8String:p_value.utf8().get_data()];
}

static String json_string(NSDictionary *p_payload) {
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:p_payload options:0 error:&error];
	if (data == nil || error != nil) {
		return String("{\"ok\":false,\"err\":\"secure_credential_invalid_response\"}");
	}
	NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return String::utf8([json UTF8String]);
}

static String failure(NSString *p_code) {
	return json_string(@{ @"ok" : @NO, @"err" : p_code });
}

static NSData *application_tag(const String &p_key_alias) {
	NSString *alias = to_ns_string(p_key_alias);
	if (alias == nil || alias.length == 0 || alias.length > 128) {
		return nil;
	}
	NSString *tag = [@"com.swarmfront.entap." stringByAppendingString:alias];
	return [tag dataUsingEncoding:NSUTF8StringEncoding];
}

static SecKeyRef copy_private_key(NSData *p_tag, OSStatus *r_status = nullptr) {
	NSDictionary *query = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassKey,
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrApplicationTag : p_tag,
		(__bridge id)kSecReturnRef : @YES,
	};
	CFTypeRef result = nullptr;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
	if (r_status != nullptr) {
		*r_status = status;
	}
	return status == errSecSuccess ? (SecKeyRef)result : nullptr;
}

static NSString *base64url(NSData *p_data) {
	NSString *encoded = [p_data base64EncodedStringWithOptions:0];
	encoded = [encoded stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
	encoded = [encoded stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	return [encoded stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

static NSDictionary *public_jwk(SecKeyRef p_private_key) {
	SecKeyRef public_key = SecKeyCopyPublicKey(p_private_key);
	if (public_key == nullptr) {
		return nil;
	}
	CFErrorRef error = nullptr;
	CFDataRef representation = SecKeyCopyExternalRepresentation(public_key, &error);
	CFRelease(public_key);
	if (representation == nullptr) {
		if (error != nullptr) {
			CFRelease(error);
		}
		return nil;
	}
	NSData *point = CFBridgingRelease(representation);
	const uint8_t *bytes = static_cast<const uint8_t *>(point.bytes);
	if (point.length != 65 || bytes[0] != 0x04) {
		return nil;
	}
	NSData *x = [NSData dataWithBytes:bytes + 1 length:32];
	NSData *y = [NSData dataWithBytes:bytes + 33 length:32];
	return @{
		@"kty" : @"EC",
		@"crv" : @"P-256",
		@"x" : base64url(x),
		@"y" : base64url(y),
		@"alg" : @"ES256",
		@"use" : @"sig",
	};
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
#if TARGET_OS_SIMULATOR
	return false;
#else
	return true;
#endif
}

String SwarmfrontSecureCredentials::create_device_key(const String &p_key_alias) {
	if (!is_available()) {
		return failure(@"secure_credential_store_unavailable");
	}
	NSData *tag = application_tag(p_key_alias);
	if (tag == nil) {
		return failure(@"invalid_key_alias");
	}
	SecKeyRef private_key = copy_private_key(tag);
	if (private_key == nullptr) {
		NSDictionary *attributes = @{
			(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
			(__bridge id)kSecAttrKeySizeInBits : @256,
			(__bridge id)kSecAttrTokenID : (__bridge id)kSecAttrTokenIDSecureEnclave,
			(__bridge id)kSecPrivateKeyAttrs : @{
				(__bridge id)kSecAttrIsPermanent : @YES,
				(__bridge id)kSecAttrApplicationTag : tag,
				(__bridge id)kSecAttrAccessible : (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
			},
		};
		CFErrorRef error = nullptr;
		private_key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
		if (error != nullptr) {
			CFRelease(error);
		}
	}
	if (private_key == nullptr) {
		return failure(@"secure_credential_operation_failed");
	}
	NSDictionary *jwk = public_jwk(private_key);
	CFRelease(private_key);
	if (jwk == nil) {
		return failure(@"invalid_public_key");
	}
	return json_string(@{
		@"ok" : @YES,
		@"key_alias" : to_ns_string(p_key_alias),
		@"algorithm" : [NSString stringWithUTF8String:ALGORITHM],
		@"jwk" : jwk,
	});
}

String SwarmfrontSecureCredentials::public_key_jwk(const String &p_key_alias) {
	NSData *tag = application_tag(p_key_alias);
	if (tag == nil) {
		return failure(@"invalid_key_alias");
	}
	SecKeyRef private_key = copy_private_key(tag);
	if (private_key == nullptr) {
		return failure(@"device_key_not_found");
	}
	NSDictionary *jwk = public_jwk(private_key);
	CFRelease(private_key);
	return jwk == nil ? failure(@"invalid_public_key") : json_string(@{ @"ok" : @YES, @"jwk" : jwk });
}

String SwarmfrontSecureCredentials::sign_challenge(const String &p_key_alias, const String &p_challenge_utf8) {
	if (p_challenge_utf8.is_empty()) {
		return failure(@"invalid_challenge");
	}
	NSData *tag = application_tag(p_key_alias);
	if (tag == nil) {
		return failure(@"invalid_key_alias");
	}
	SecKeyRef private_key = copy_private_key(tag);
	if (private_key == nullptr) {
		return failure(@"device_key_not_found");
	}
	NSData *message = [to_ns_string(p_challenge_utf8) dataUsingEncoding:NSUTF8StringEncoding];
	CFErrorRef error = nullptr;
	CFDataRef signature = SecKeyCreateSignature(
			private_key,
			kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
			(__bridge CFDataRef)message,
			&error);
	CFRelease(private_key);
	if (error != nullptr) {
		CFRelease(error);
	}
	if (signature == nullptr) {
		return failure(@"secure_credential_operation_failed");
	}
	NSData *der_signature = CFBridgingRelease(signature);
	return json_string(@{
		@"ok" : @YES,
		@"algorithm" : [NSString stringWithUTF8String:ALGORITHM],
		@"signature" : base64url(der_signature),
	});
}

String SwarmfrontSecureCredentials::delete_device_key(const String &p_key_alias) {
	NSData *tag = application_tag(p_key_alias);
	if (tag == nil) {
		return failure(@"invalid_key_alias");
	}
	NSDictionary *query = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassKey,
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrApplicationTag : tag,
	};
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
	if (status != errSecSuccess && status != errSecItemNotFound) {
		return failure(@"secure_credential_operation_failed");
	}
	return json_string(@{ @"ok" : @YES });
}
