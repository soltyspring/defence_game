extends SceneTree
## 07-qa: colour-vision-deficiency simulation of a captured PNG (Machado, Oliveira & Fernandes 2009,
## severity 1.0, applied in linear RGB). Headless.
##   Godot_console --headless --path . -s res://tests/acceptance/cvd_sim.gd -- --in=<abs.png> --out-prefix=<abs prefix>
## Writes <prefix>_protan.png, <prefix>_deutan.png, <prefix>_tritan.png. Owner: 07-qa.

const M := {
	"protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}

func _initialize() -> void:
	var src := ""
	var pre := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="): src = a.get_slice("=", 1)
		elif a.begins_with("--out-prefix="): pre = a.get_slice("=", 1)
	var img := Image.load_from_file(src)
	if img == null:
		printerr("cannot load ", src); quit(1); return
	img.convert(Image.FORMAT_RGBA8)
	var lut := PackedFloat32Array(); lut.resize(256)
	for i in 256:
		var v := i / 255.0
		lut[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	for kind in M:
		var m: Array = M[kind]
		var out := img.duplicate()
		var data := img.get_data()
		var o := PackedByteArray(); o.resize(data.size())
		for i in range(0, data.size(), 4):
			var r := lut[data[i]]; var g := lut[data[i + 1]]; var b := lut[data[i + 2]]
			for c in 3:
				var v: float = m[c][0] * r + m[c][1] * g + m[c][2] * b
				v = clampf(12.92 * v if v <= 0.0031308 else 1.055 * pow(maxf(v, 0.0), 1.0 / 2.4) - 0.055, 0.0, 1.0)
				o[i + c] = int(roundf(v * 255.0))
			o[i + 3] = data[i + 3]
		out.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, o)
		out.save_png("%s_%s.png" % [pre, kind])
	print("[cvd] wrote ", pre, "_{protan,deutan,tritan}.png")
	quit(0)
