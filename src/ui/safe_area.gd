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
## Test hook: emulate a phone's density. Minimum touch target in logical units (48 dp converted for that
## device: e.g. 1080x2400 @ 3.0 → 48, @ 2.75 → 44; 1440x3200 @ 3.5 at k=4 → 42). 0 = use the real screen.
static var override_target := 0.0

static func view_size(vp: Viewport) -> Vector2:
	if override_view_size != Vector2.ZERO:
		return override_view_size
	return vp.get_visible_rect().size

## Safe area in logical units. Converts DisplayServer pixels using the window→viewport ratio.
## Only phones/tablets report a real safe area (cutouts). On desktop, Windows reports the screen's WORK
## area (minus the taskbar) as the "safe area": in borderless fullscreen on a 1080 px monitor with a 48 px
## taskbar that became a 16 px bottom inset and lifted the bottom HUD row into the lane (11–13 px of unit
## sprites covered, store captures 13aade1). Desktop therefore uses the full view.
static func safe_rect(vp: Viewport) -> Rect2:
	var vs := view_size(vp)
	if override_insets != Vector4.ZERO:
		return Rect2(override_insets.x, override_insets.y, vs.x - override_insets.x - override_insets.z, vs.y - override_insets.y - override_insets.w)
	if override_safe_rect.size != Vector2.ZERO:
		return override_safe_rect
	if DisplayServer.get_name() == "headless":
		return Rect2(Vector2.ZERO, vs)
	return from_display(vs, Vector2(DisplayServer.window_get_size()), Vector2(DisplayServer.window_get_position()),
		Rect2(DisplayServer.get_display_safe_area()), OS.has_feature("mobile"))

## Pure conversion (unit-tested): display safe area in window pixels → logical safe rect.
static func from_display(vs: Vector2, win: Vector2, win_pos: Vector2, sa: Rect2, mobile: bool) -> Rect2:
	var full := Rect2(Vector2.ZERO, vs)
	if not mobile:
		return full
	if win.x <= 0 or win.y <= 0 or sa.size.x <= 0 or sa.size.y <= 0:
		return full
	var k := vs / win
	var r := Rect2((sa.position - win_pos) * k, sa.size * k)
	r = r.intersection(full)
	if r.size.x < vs.x * 0.6 or r.size.y < vs.y * 0.6:
		return full  # implausible report
	return r

## Minimum touch target in logical units for the current screen.
static func min_target(vp: Viewport) -> float:
	if override_target > 0.0:
		return clampf(override_target, MIN_TARGET_LOGICAL, MAX_TARGET_LOGICAL)
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
