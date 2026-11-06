extends AudioStreamPlayer
class_name MusicPlayer

# The arena's background music. It plays on the "Music" bus (the pause menu's Music volume slider),
# loops forever, and keeps playing while the game is paused. It starts on "FIGHT!", and speeds up as
# the shrinking zone closes (ShrinkingZone.get_progress()).
#
# The track is a WAV on purpose: Godot's MP3 looping restarts the decoder at the end and leaves
# about 55 ms of silence at every loop, while a WAV loops sample-exactly. To change the track, give
# it a WAV that is already trimmed to the loop length (no silence at either end) and assign it as
# `stream`; Ogg and MP3 also work, but they will not loop as cleanly.

## Tempo multiplier when the zone is at its smallest (1.25 = 25% faster).
@export_range(1.0, 2.0) var max_tempo: float = 1.25
## How fast the tempo may change (multiplier per second), so a zone that is switched on or off glides.
@export var tempo_change_rate: float = 0.08
## Keep the key while the tempo changes (a pitch shifter on the Music bus undoes the rise in pitch).
## Turn it off to let the pitch rise with the tempo instead.
@export var keep_pitch: bool = true

var _tempo: float = 1.0
var _shifter: AudioEffectPitchShift
var _zone: ShrinkingZone


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the pause menu must not cut the music
	bus = Sfx.BUS_MUSIC
	_make_loop(stream)
	_add_shifter()
	_start_after_countdown()


func _exit_tree() -> void:
	_remove_shifter()
	pitch_scale = 1.0


func _process(delta: float) -> void:
	if _zone == null or not is_instance_valid(_zone):
		_zone = get_tree().get_first_node_in_group("zone") as ShrinkingZone
	var progress := _zone.get_progress() if _zone else 0.0
	var target := lerpf(1.0, max_tempo, progress)
	_tempo = move_toward(_tempo, target, tempo_change_rate * delta)
	_apply_tempo()


## The music begins on "FIGHT!", not during the 3-2-1.
func _start_after_countdown() -> void:
	await get_tree().process_frame # the countdown sets its flag in its own _ready, so look after the tree is ready
	while FightCountdown.active:
		await get_tree().process_frame
	if stream and not playing:
		play()


## Playing faster raises the pitch by the same factor; the shifter lowers it back.
func _apply_tempo() -> void:
	pitch_scale = _tempo
	if _shifter == null:
		return
	var bus_index := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	var effect_index := _shifter_index(bus_index)
	if effect_index < 0:
		return
	var needed := keep_pitch and _tempo > 1.001 # at normal speed the effect is bypassed, so the sound stays untouched
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, needed)
	_shifter.pitch_scale = 1.0 / _tempo if needed else 1.0


func _add_shifter() -> void:
	var bus_index := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	if bus_index < 0:
		return
	_shifter = AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus_index, _shifter)
	AudioServer.set_bus_effect_enabled(bus_index, _shifter_index(bus_index), false)


func _remove_shifter() -> void:
	var bus_index := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	var effect_index := _shifter_index(bus_index)
	if bus_index >= 0 and effect_index >= 0:
		AudioServer.remove_bus_effect(bus_index, effect_index)
	_shifter = null


func _shifter_index(bus_index: int) -> int:
	if bus_index < 0 or _shifter == null:
		return -1
	for i in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i) == _shifter:
			return i
	return -1


## Sets the stream to loop over its whole length.
func _make_loop(track: AudioStream) -> void:
	if track is AudioStreamWAV:
		var wav := track as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate)) # in sample frames
	elif track is AudioStreamMP3:
		(track as AudioStreamMP3).loop = true
	elif track is AudioStreamOggVorbis:
		(track as AudioStreamOggVorbis).loop = true
