#include "swarmfront_secure_credentials.h"

#include "core/config/engine.h"

static SwarmfrontSecureCredentials *credential_store = nullptr;

void godot_swarmfront_secure_credentials_init() {
	credential_store = memnew(SwarmfrontSecureCredentials);
	Engine::get_singleton()->add_singleton(
			Engine::Singleton("SwarmfrontSecureCredentials", credential_store));
}

void godot_swarmfront_secure_credentials_deinit() {
	if (credential_store != nullptr) {
		memdelete(credential_store);
		credential_store = nullptr;
	}
}
