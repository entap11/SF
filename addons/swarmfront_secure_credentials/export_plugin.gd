@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	_export_plugin = AndroidSecureCredentialsExportPlugin.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null

class AndroidSecureCredentialsExportPlugin extends EditorExportPlugin:
	const PLUGIN_DIRECTORY: String = "swarmfront_secure_credentials"
	const LIBRARY_NAME: String = "SwarmfrontSecureCredentials"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var variant: String = "debug" if debug else "release"
		return PackedStringArray([
			"%s/bin/%s/%s-%s.aar" % [PLUGIN_DIRECTORY, variant, LIBRARY_NAME, variant]
		])

	func _get_name() -> String:
		return LIBRARY_NAME
