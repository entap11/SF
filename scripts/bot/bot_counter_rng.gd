class_name BotCounterRng
extends RefCounted

const RNG_VERSION: String = "counter_sha256_v1"


static func sample_u32(
	match_seed: int,
	policy_version: String,
	profile_hash: String,
	seat: int,
	decision_sequence: int,
	purpose_salt: String
) -> int:
	var key := "%d|%s|%s|%d|%d|%s" % [
		match_seed,
		policy_version,
		profile_hash,
		seat,
		decision_sequence,
		purpose_salt
	]
	var digest: PackedByteArray = key.sha256_buffer()
	return (
		(int(digest[0]) << 24)
		| (int(digest[1]) << 16)
		| (int(digest[2]) << 8)
		| int(digest[3])
	)


static func range_inclusive(
	minimum: int,
	maximum: int,
	match_seed: int,
	policy_version: String,
	profile_hash: String,
	seat: int,
	decision_sequence: int,
	purpose_salt: String
) -> int:
	if maximum <= minimum:
		return minimum
	var width: int = maximum - minimum + 1
	var sample: int = sample_u32(
		match_seed,
		policy_version,
		profile_hash,
		seat,
		decision_sequence,
		purpose_salt
	)
	return minimum + int(sample % width)
