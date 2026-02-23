class_name BetaRuntimeBannerRuntime
extends RefCounted

const TREE_META_BETA_RUNTIME_FLAGS: String = "beta_runtime_flags"

var _runtime_sig_cache: int = 0

func refresh(tree: SceneTree, handshake: Node, force: bool = false) -> Dictionary:
	if tree == null:
		return {"changed": false, "visible": false, "notice": "", "flags": {}}
	var flags: Dictionary = _build_flags(handshake)
	tree.set_meta(TREE_META_BETA_RUNTIME_FLAGS, flags)
	var visible: bool = bool(flags.get("competitive_provisional", true))
	var notice: String = _build_notice(flags)
	var sig: int = hash([visible, notice, flags])
	if not force and sig == _runtime_sig_cache:
		return {"changed": false, "visible": visible, "notice": notice, "flags": flags}
	_runtime_sig_cache = sig
	return {"changed": true, "visible": visible, "notice": notice, "flags": flags}

func _build_flags(handshake: Node) -> Dictionary:
	if handshake != null and handshake.has_method("get_beta_runtime_flags"):
		var from_handshake: Variant = handshake.call("get_beta_runtime_flags")
		if typeof(from_handshake) == TYPE_DICTIONARY:
			return from_handshake as Dictionary
	var transport_mode: String = "local"
	if handshake != null and handshake.has_method("get_transport_mode"):
		transport_mode = str(handshake.call("get_transport_mode"))
	var online: bool = transport_mode == "http"
	if handshake != null and handshake.has_method("is_authoritative_transport_online"):
		online = bool(handshake.call("is_authoritative_transport_online"))
	return {
		"match_authority": "local_ops_state",
		"progression_authority": "remote_authoritative" if online else "local_provisional",
		"transport_mode": transport_mode,
		"competitive_provisional": not online,
		"authoritative_progression_online": online
	}

func _build_notice(flags: Dictionary) -> String:
	if not bool(flags.get("competitive_provisional", true)):
		return ""
	return "Beta mode: match sim is local-authoritative; cross-device competitive progression is provisional."
