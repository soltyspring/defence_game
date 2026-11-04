extends RefCounted
## One raster grid for camera translation and every parallax layer. Values remain
## in world coordinates; only the final translation is quantized to device pixels.
## In production zoom=(k+1)/k, hence every atlas pixel is exactly k+1 device pixels.

static func center(wanted: float, viewport_extent: float, zoom: float, device_scale: float) -> float:
	var z := maxf(0.001, zoom)
	var k := maxf(1.0, device_scale)
	var translation := (viewport_extent * 0.5 - wanted * z) * k
	return (viewport_extent * 0.5 - floorf(translation + 0.5) / k) / z

static func world_position(wanted: float, zoom: float, device_scale: float) -> float:
	var pixels := maxf(0.001, zoom * maxf(1.0, device_scale))
	return floorf(wanted * pixels + 0.5) / pixels

static func layer_origin(camera: float, parallax: float, zoom: float, device_scale: float) -> float:
	return world_position(camera * (1.0 - parallax), zoom, device_scale)
