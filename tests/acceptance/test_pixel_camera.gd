extends SceneTree
## Raster invariants, independent of the production scene/autoloads. This checks
## pixel phase and continuity, not screenshots or subjective motion quality.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 5: printerr("FAIL raster: ", message)

func _initialize() -> void:
	for scale in [1.0, 2.0, 3.0, 4.0]:
		var zoom: float = (scale + 1.0) / scale
		for extent in [640.0, 800.0, 853.5, 640.25]:
			for wanted in [-900.35, -90.0, -0.51, 0.0, 151.2, 999.99, 5000.71]:
				var camera := Raster.center(wanted, extent, zoom, scale)
				var translation: float = (extent * 0.5 - camera * zoom) * scale
				check(absf(translation - roundf(translation)) < 0.00001, "camera translation is a device pixel")
				check(absf((camera - wanted) * zoom * scale) <= 0.50001, "quantization is at most half a device pixel")
				for parallax in [0.0, 0.15, 0.45, 1.0, 1.15]:
					var origin := Raster.layer_origin(camera, parallax, zoom, scale)
					var left: float = (origin - camera) * zoom * scale + extent * 0.5 * scale
					var right: float = (origin + 640.0 - camera) * zoom * scale + extent * 0.5 * scale
					check(absf(left - roundf(left)) < 0.00001, "parallax shares the camera raster phase")
					check(is_equal_approx(right - left, 640.0 * (scale + 1.0)), "repeated tile width stays exact")
			var previous := 0.0
			for frame in 240:
				var camera := Raster.center(100.0 + frame * 0.05, extent, zoom, scale)
				var projected: float = (extent * 0.5 - camera * zoom) * scale
				if frame > 0:
					check(projected <= previous + 0.00001, "camera never reverses while moving forward")
					check(previous - projected <= 1.00001, "slow travel never jumps multiple device pixels")
				previous = projected
	print("[pixel_camera] passed=", checks - failures, " failed=", failures)
	quit(0 if failures == 0 else 1)
