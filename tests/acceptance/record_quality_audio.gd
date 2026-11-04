extends SceneTree
## Bounded recording of isolated replacement cues, then a normal-speed real r08 battle.
## No system device/settings changes. Use private APPDATA and a visible normal-audio run.
var app: Node
var audio: Node
var effects := {}
var out := "user://quality-audio"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality-out="): out = arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(out)
	app = root.get_node("App")
	audio = root.get_node("Audio")
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await create_timer(0.3).timeout
	# AudioEffectRecord exposes its last stereo-pair instance on a 7.1 output.
	# In the probe ONLY, mirror the ordinary stereo mix to all pairs so that the
	# recorded last pair carries the same signal as the front pair. Runtime routing
	# and the system's output device/configuration remain unchanged.
	var mirrored := AudioServer.get_speaker_mode() != AudioServer.SPEAKER_MODE_STEREO
	if mirrored:
		for player in audio.get_children():
			if player is AudioStreamPlayer: player.mix_target = AudioStreamPlayer.MIX_TARGET_SURROUND
	for bus in ["Master","SFX"]:
		var effect := AudioEffectRecord.new()
		effect.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus),effect)
		effects[bus] = effect
	await create_timer(0.1).timeout
	for effect in effects.values(): effect.set_recording_active(true)
	for i in 12:
		audio.play([&"hit_melee",&"hit_bread",&"hit_mold"][i%3],{})
		await create_timer(0.48).timeout
	audio.play(&"flour_delivery",{})
	await create_timer(0.8).timeout
	audio.play(&"ui_scout",{})
	await create_timer(0.8).timeout
	app.autoplay = true
	app.start_round("r08",true)
	await create_timer(35.0).timeout
	for effect in effects.values(): effect.set_recording_active(false)
	await create_timer(0.1).timeout
	var samples := {}
	var has_audio := true
	for bus in effects:
		var wav: AudioStreamWAV = effects[bus].get_recording()
		wav.save_to_wav(out.path_join("quality_%s.wav" % bus.to_lower()))
		samples[bus] = {"bytes":wav.data.size(),"rate":wav.mix_rate,"seconds":wav.get_length()}
		if wav.data.count(0) >= wav.data.size() * 0.99: has_audio = false
	var result := {"mode":"12 isolated hits + delivery/scout, then r08 autoplay 35s at normal speed", "driver":AudioServer.get_driver_name(),"speaker_mode":AudioServer.get_speaker_mode(),"probe_mirrors_stereo_pairs":mirrored,"contains_audio":has_audio,"audio":audio.snapshot(),"recordings":samples,"sim_t":app.battle.sim.t if app.battle else -1.0}
	FileAccess.open(out.path_join("audio-mix.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QUALITY_AUDIO ",JSON.stringify(result))
	app.show_screen(&"menu")
	audio.prepare_quit()
	await create_timer(0.2).timeout
	quit(0 if has_audio and int(audio.stats.missing) == 0 and audio.load_errors.is_empty() else 1)
