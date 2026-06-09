extends SceneTree

const AUDIO_PATHS: Array[String] = [
	"res://assets/sprites/sf_skin_v1/sf_sounds/mm_ambient.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/mm_base_drop.mp3",
	"res://assets/sprites/sf_skin_v1/sf_sounds/store_purchase.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/matchmaker.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/jukebox_play.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/buff_equip.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/game_prematch_countdown.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/game_tower_shot.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/game_swarm.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/game_lose_hive.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/win_hive.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/win_song.mp3",
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song2.ogg",
	"res://assets/sprites/sf_skin_v1/sf_sounds/lose_song3.ogg"
]

func _init() -> void:
	await process_frame
	for path in AUDIO_PATHS:
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			push_error("AUDIO_ASSETS_SMOKE: missing or non-audio asset %s" % path)
			quit(1)
			return
	print("AUDIO_ASSETS_SMOKE: PASS assets=%d" % AUDIO_PATHS.size())
	quit(0)
