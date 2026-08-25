#include "swarmfront_secure_credentials_module.h"

#include "core/config/engine.h"
#include "swarmfront_secure_credentials.h"

static SwarmfrontSecureCredentials *swarmfront_secure_credentials = nullptr;

void swarmfront_secure_credentials_init() {
	swarmfront_secure_credentials = memnew(SwarmfrontSecureCredentials);
	Engine::get_singleton()->add_singleton(
			Engine::Singleton("SwarmfrontSecureCredentials", swarmfront_secure_credentials));
}

void swarmfront_secure_credentials_deinit() {
	if (swarmfront_secure_credentials != nullptr) {
		memdelete(swarmfront_secure_credentials);
		swarmfront_secure_credentials = nullptr;
	}
}
