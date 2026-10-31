extends RefCounted
## Safe-area and touch-target metrics in logical (viewport) coordinates. Owner: 04-client.
## Base viewport 640x360, stretch canvas_items + expand (ENGINE.md §4): logical width grows on wide phones.

const MIN_TARGET_DP := 48.0        # Android / Material minimum touch target
const MIN_TARGET_LOGICAL := 40.0   # floor in 640x360 units (≈48dp on common 720p–1080p phones)
const MAX_TARGET_LOGICAL := 56.0
const EDGE_MARGIN := 4.0

## Test hook: when set (size > 0) overrides the platform safe area, in logical units.
static var override_safe_rect := Rect2()
## Test hook: simulated notch insets (left, top, right, bottom) applied to the CURRENT view size.
## Preferred over override_safe_rect: a fixed rect captured at startup goes stale when the window or
## the integer-scale view (e.g. 800×450 at 1600×900) changes afterwards (seen 15:42).
static var override_insets := Vector4()
static var override_view_size := Vector2()

static func view_size(vp: Viewport) -> Vector2:
	if override_view_size != Vector2.ZERO:
		return override_view_size
	return vp.get_visible_rect().size

## Safe area in logical units. Converts DisplayServer pixels using the window→viewport ratio.
static func safe_rect(vp: Viewport) -> Rect2:
	var vs := view_size(vp)
	if override_insets != Vector4.ZERO:
		return Rect2(override_insets.x, override_insets.y, vs.x - override_insets.x - override_insets.z, vs.y - override_insets.y - override_insets.w)
	if override_safe_rect.size != Vector2.ZERO:
		return override_safe_rect
	var full := Rect2(Vector2.ZERO, vs)
	if DisplayServer.get_name() == "headless":
		return full
	var win := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or sa.size.x <= 0 or sa.size.y <= 0:
		return full
	var win_pos := Vector2(DisplayServer.window_get_position())
	var k := vs / win
	var r := Rect2((Vector2(sa.position) - win_pos) * k, Vector2(sa.size) * k)
	r = r.intersection(full)
	if r.size.x < vs.x * 0.6 or r.size.y < vs.y * 0.6:
		return full  # implausible report (desktop multi-monitor etc.)
	return r

## Minimum touch target in logical units for the current screen.
static func min_target(vp: Viewport) -> float:
	if DisplayServer.get_name() == "headless" or override_view_size != Vector2.ZERO:
		return MIN_TARGET_LOGICAL
	var dpi := float(DisplayServer.screen_get_dpi())
	var win := Vector2(DisplayServer.window_get_size())
	var vs := view_size(vp)
	if dpi <= 0 or win.y <= 0 or vs.y <= 0:
		return MIN_TARGET_LOGICAL
	var px := MIN_TARGET_DP * dpi / 160.0
	var logical := px / (win.y / vs.y)
	return clampf(logical, MIN_TARGET_LOGICAL, MAX_TARGET_LOGICAL)
