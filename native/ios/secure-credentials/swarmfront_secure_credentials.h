#ifndef SWARMFRONT_SECURE_CREDENTIALS_H
#define SWARMFRONT_SECURE_CREDENTIALS_H

#include "core/object/class_db.h"

class SwarmfrontSecureCredentials : public Object {
	GDCLASS(SwarmfrontSecureCredentials, Object);

	static void _bind_methods();

public:
	bool is_available() const;
	String create_device_key(const String &p_key_alias);
	String public_key_jwk(const String &p_key_alias);
	String sign_challenge(const String &p_key_alias, const String &p_challenge_utf8);
	String delete_device_key(const String &p_key_alias);
};

#endif
