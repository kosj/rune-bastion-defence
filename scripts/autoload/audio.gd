extends Node
## Sound effect pool + music crossfader.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 14

var _pool: Array[AudioStreamPlayer] = []
var _streams := {}
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)

func _get_stream(name: String, dir := SFX_DIR) -> AudioStream:
	var key := dir + name
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	for ext in [".ogg", ".mp3", ".wav"]:
		if ResourceLoader.exists(dir + name + ext):
			s = load(dir + name + ext)
			break
	_streams[key] = s
	return s

const VOICE_DIR := "res://assets/audio/voice/"
var _voice: AudioStreamPlayer
var _voice_last := {}

## Spoken line (hero barks, announcer). One at a time; each line has its own cooldown.
func voice(name: String, volume_db := 0.0, cooldown := 4.0) -> void:
	if Game.sfx_volume <= 0.01:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_voice_last.get(name, -99.0)) < cooldown:
		return
	var s := _get_stream(name, VOICE_DIR)
	if s == null:
		return
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		add_child(_voice)
	var important := name.begins_with("ann_")
	if _voice.playing and not important:
		return
	_voice_last[name] = now
	_voice.stream = s
	_voice.volume_db = volume_db + linear_to_db(maxf(Game.sfx_volume, 0.001))
	_voice.play()
	# duck the music a little under speech
	if _music_a and _music_a.playing:
		var base := linear_to_db(maxf(Game.music_volume * 0.55, 0.001))
		var tw := create_tween()
		tw.tween_property(_music_a, "volume_db", base - 6.0, 0.15)
		tw.tween_interval(maxf(s.get_length() - 0.2, 0.3))
		tw.tween_property(_music_a, "volume_db", base, 0.5)

## Play a sound. `name` may have variants name_1..name_N (pass variants=N).
func play(name: String, volume_db := 0.0, pitch_var := 0.08, variants := 0) -> void:
	if Game.sfx_volume <= 0.01:
		return
	var key := name
	if variants > 0:
		key = "%s_%d" % [name, randi() % variants + 1]
	var now := Time.get_ticks_msec()
	if _last_play.has(name) and now - int(_last_play[name]) < 45:
		return
	_last_play[name] = now
	var s := _get_stream(key)
	if s == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[randi() % _pool.size()]
	player.stream = s
	player.volume_db = volume_db + linear_to_db(maxf(Game.sfx_volume, 0.001))
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.play()

func play_music(name: String, fade := 1.2) -> void:
	if name == _music_current:
		return
	_music_current = name
	var stream: AudioStream = _get_stream(name, MUSIC_DIR)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var old := _music_a
	var nw := _music_b
	_music_a = nw
	_music_b = old
	nw.stream = stream
	nw.volume_db = -40.0
	nw.play()
	var target := linear_to_db(maxf(Game.music_volume * 0.55, 0.001))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nw, "volume_db", target, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)

func update_music_volume() -> void:
	if _music_a.playing:
		_music_a.volume_db = linear_to_db(maxf(Game.music_volume * 0.55, 0.001))
