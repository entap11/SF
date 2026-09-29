extends RefCounted

const Definitions := preload("res://scripts/state/buff_definitions.gd")

static func description(buff: Dictionary) -> String:
	var id: String = str(buff.get("canonical_id", ""))
	var effects: Dictionary = Definitions.effect_payload_for(id)
	var text: String = ""
	match id:
		Definitions.UNIT_SWARM_DAMAGE:
			text = "Your swarms deal %s× damage in swarm combat. Hive impact damage stays the same." % str(effects.get("swarm_combat_damage_mult", 2))
		Definitions.UNIT_HIVE_IMPACT_DAMAGE:
			text = "New bees carry %s× hive impact damage. Their bonus remains after the buff ends, until spent in combat." % str(effects.get("hive_impact_damage_mult", 2))
		Definitions.UNIT_SPEED:
			text = "New bees from the selected hive fly %d%% faster and keep their speed after the buff ends." % int(round((float(effects.get("unit_speed_mult", 1.0)) - 1.0) * 100.0))
		Definitions.HIVE_SINGLE_PRODUCTION_BOOST:
			text = "The selected hive produces bees in %d%% less time." % int(round((1.0 - float(effects.get("production_time_mult", 1.0))) * 100.0))
		Definitions.HIVE_GLOBAL_PRODUCTION_BOOST:
			text = "Your currently owned hives produce bees in %d%% less time. Later captures are excluded." % int(round((1.0 - float(effects.get("production_time_mult", 1.0))) * 100.0))
		Definitions.HIVE_SHIELD_SINGLE:
			text = "Protect the selected hive from landing-bee damage. Shock effects remain possible."
		Definitions.HIVE_SHIELD_GLOBAL:
			text = "Protect your currently owned hives from landing-bee damage. Later captures are excluded; shock effects remain possible."
		Definitions.HIVE_SHOCK_IMMUNITY:
			text = "Protect the selected hive from shock. Landing bees can still damage it."
		Definitions.HIVE_GLOBAL_SHOCK_IMMUNITY:
			text = "Protect your currently owned hives from shock. Later captures are excluded; landing bees can still damage them."
		Definitions.HIVE_SUPERCHARGE_QUEUE:
			text = "Bank bonus bees on one outgoing lane while normal traffic continues. The queue releases when charging ends; losing its source or sending direction forfeits it."
		Definitions.LANE_FREEZE:
			text = "Stop enemy advance on one lane. Your bees keep moving, and combat continues."
		Definitions.LANE_TREACHEROUS:
			text = "Turn enemy bees back toward their source hive. New enemy bees produced onto this lane also turn while active. Turned bees keep returning after expiry."
	return text

static func scope(buff: Dictionary) -> String:
	match str(buff.get("target_type", "none")):
		"hive": return "One hive"
		"lane": return "One lane"
	return "Global"

static func timing(buff: Dictionary) -> String:
	return "%s · %ss" % [scope(buff), str(float(buff.get("duration_sec", 0.0)))]
