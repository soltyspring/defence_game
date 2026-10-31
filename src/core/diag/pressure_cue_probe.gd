extends SceneTree
## QA-B017 check: an idle player in r01 gets exactly one `counterattack` cue, at the first pressure wave time,
## and the HUD wave counter never counts pressure waves. Also renders the engine fallback menu title text.
## Run: tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/pressure_cue_probe.gd
##   with a PRIVATE APPDATA (Save boots as an autoload): & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(<same args>)
## Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")

func _initialize() -> void:
	var c = ContentS.new()
	c.load_all("res://data")
	var rid: String = c.round_order[0]
	var sim = SimS.new()
	sim.setup(c, rid, 11)
	sim.time_limit = 0.0
	var cues := []
	var wave_ev := []
	var max_total := 0
	var dt := 1.0 / 60.0
	while not sim.ended and sim.t < 400.0:
		sim.step(dt)
		for e in sim.events:
			if e[0] == "counterattack": cues.append([snappedf(sim.t, 0.01), e[1]])
			if e[0] == "wave": wave_ev.append(int(e[1].index))
		sim.events.clear()
		sim.cues.clear()
		max_total = maxi(max_total, int(sim.current_wave().total))
	var pressure_cues := cues.filter(func(x): return x[1].get("pressure", false))
	var ok: bool = pressure_cues.size() == 1 and absf(float(pressure_cues[0][0]) - float(sim.pressure_times.min())) < 0.05 and max_total == sim.waves_total
	var title: String = load("res://src/gameplay/fallback_ui.gd")._title()
	print("PRESSURE_CUE_PROBE ", JSON.stringify({"round": rid, "pressure_times": sim.pressure_times, "counterattack_events": cues,
		"wave_events": wave_ev, "hud_wave_total_max": max_total, "scripted_waves": sim.waves_total, "ended_t": snappedf(sim.t, 0.1),
		"won": sim.won, "fallback_title": title, "pass": ok and title != "" and not title.contains("LANE")}))
	c.free()
	quit(0)
