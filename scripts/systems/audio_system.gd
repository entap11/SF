class_name AudioSystem
extends RefCounted

const TIE_SFX_COOLDOWN_US := 500_000
const COIN_SFX_SEC := 0.08
const COIN_SFX_FREQ := 880.0

var _coin_player: AudioStreamPlayer = null
var _last_coin_sfx_us: Dictionary = {}

func setup(coin_player: AudioStreamPlayer) -> void:
	_coin_player = coin_player

func reset() -> void:
	_last_coin_sfx_us.clear()

func handle_events(events: Array, sim_time_us: int) -> void:
	for event in events:
		var event_type: String = str(event.get("type", ""))
		match event_type:
			"coin_flip":
				_play_coin_flip_sfx(int(event.get("hive_id", -1)), sim_time_us)
			"barracks_active":
				_play_barracks_activate_sfx()

func _play_coin_flip_sfx(hive_id: int, sim_time_us: int) -> void:
	if hive_id == -1:
		return
	if _coin_player == null:
		return
	var last_us: int = int(_last_coin_sfx_us.get(hive_id, 0))
	if sim_time_us - last_us < TIE_SFX_COOLDOWN_US:
		return
	_last_coin_sfx_us[hive_id] = sim_time_us
	if _coin_player.stream == null:
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = 44100
		gen.buffer_length = 0.1
		_coin_player.stream = gen
	if not _coin_player.playing:
		_coin_player.play()
	var playback: AudioStreamGeneratorPlayback = _coin_player.get_stream_playback()
	if playback == null:
		return
	var frames_needed: int = int(COIN_SFX_SEC * 44100.0)
	var frames_available: int = playback.get_frames_available()
	var frames: int = min(frames_needed, frames_available)
	for i in range(frames):
		var t: float = float(i) / 44100.0
		var amp: float = 0.3 * exp(-t * 20.0)
		var s: float = sin(t * TAU * COIN_SFX_FREQ) * amp
		playback.push_frame(Vector2(s, s))

func _play_barracks_activate_sfx() -> void:
	if _coin_player == null:
		return
	if _coin_player.stream == null:
		return
	_coin_player.play()
