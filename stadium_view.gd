extends Control
## Lightweight 2D stadium renderer for the playable baseball prototype.
## Generated PNG art is composited first; procedural geometry remains as a
## deterministic fallback so the game still boots when an asset is missing.

signal pitch_arrived

var mode: String = "idle"
var pitch_kind: String = "fastball"
var pitch_zone: int = 4
var aim_zone: int = 4
var pitch_duration: float = 1.0
var pitch_elapsed: float = 0.0
var hit_elapsed: float = 0.0
var hit_target: Vector2 = Vector2(0.85, 0.18)
var flash_time: float = 0.0
var bases: Array[bool] = [false, false, false]
var stadium_texture: Texture2D
var pitcher_texture: Texture2D
var batter_texture: Texture2D
var catcher_texture: Texture2D

const NAVY := Color("102c50")
const SKY_TOP := Color("15529a")
const SKY_BOTTOM := Color("55b7d0")
const GRASS := Color("238b59")
const GRASS_LIGHT := Color("74d47d")
const DIRT := Color("cf8d4c")
const LINE := Color(0.98, 0.99, 0.93, 0.86)
const WHITE := Color("fffdf7")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    stadium_texture = load("res://assets/generated/stadium-bg-v1.png") as Texture2D
    pitcher_texture = load("res://assets/generated/pitcher-v2.png") as Texture2D
    batter_texture = load("res://assets/generated/batter-v2.png") as Texture2D
    catcher_texture = load("res://assets/generated/catcher-v2.png") as Texture2D
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    if mode == "pitch":
        pitch_elapsed += delta
        if pitch_elapsed >= pitch_duration:
            pitch_elapsed = pitch_duration
            mode = "plate"
            pitch_arrived.emit()
    elif mode == "hit":
        hit_elapsed += delta
        if hit_elapsed > 1.0:
            mode = "idle"
    if flash_time > 0.0:
        flash_time = maxf(0.0, flash_time - delta)
    queue_redraw()

func start_pitch(duration: float, kind: String, zone: int) -> void:
    pitch_duration = maxf(0.2, duration)
    pitch_kind = kind
    pitch_zone = zone
    pitch_elapsed = 0.0
    mode = "pitch"
    queue_redraw()

func get_pitch_progress() -> float:
    if mode != "pitch" and mode != "plate":
        return 0.0
    return clampf(pitch_elapsed / pitch_duration, 0.0, 1.15)

func swing_to(target: Vector2) -> void:
    hit_target = target
    hit_elapsed = 0.0
    flash_time = 0.55
    mode = "hit"
    queue_redraw()

func cancel_pitch() -> void:
    mode = "idle"
    pitch_elapsed = 0.0
    hit_elapsed = 0.0
    queue_redraw()

func set_aim_zone(zone: int) -> void:
    aim_zone = clampi(zone, 0, 8)
    queue_redraw()

func set_bases(next_bases: Array[bool]) -> void:
    bases = next_bases.duplicate()
    queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    if w < 10.0 or h < 10.0:
        return

    if stadium_texture:
        draw_texture_rect(stadium_texture, Rect2(Vector2.ZERO, Vector2(w, h)), false)
        _draw_field_overlay(w, h)
    else:
        _draw_sky(w, h)
        _draw_stands(w, h)
        _draw_field(w, h)
    _draw_characters(w, h)
    _draw_strike_zone(w, h)
    _draw_ball(w, h)
    if flash_time > 0.0:
        _draw_impact(w, h)

func _draw_sky(w: float, h: float) -> void:
    var sky_h := h * 0.43
    for index in range(12):
        var t := float(index) / 11.0
        draw_rect(Rect2(0.0, t * sky_h, w, sky_h / 11.0 + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
    _draw_ellipse(Vector2(w * 0.16, h * 0.16), Vector2(w * 0.13, h * 0.035), Color(0.52, 0.84, 0.94, 0.12))
    _draw_ellipse(Vector2(w * 0.83, h * 0.21), Vector2(w * 0.11, h * 0.028), Color(0.72, 0.94, 0.91, 0.11))
    draw_circle(Vector2(w * 0.5, h * 0.16), minf(w, h) * 0.045, Color(1.0, 0.98, 0.74, 0.30))
    draw_circle(Vector2(w * 0.5, h * 0.16), minf(w, h) * 0.075, Color(1.0, 0.92, 0.53, 0.08))

func _draw_stands(w: float, h: float) -> void:
    var top := h * 0.24
    draw_rect(Rect2(0.0, top, w, h * 0.21), Color("12375f"))
    for row in range(5):
        var y := top + float(row) * h * 0.032
        for col in range(42):
            var x := float(col) * w / 41.0 + (row % 2) * 3.0
            var dot_color := Color("23496b") if (col + row) % 3 else Color("3c7690")
            draw_circle(Vector2(x, y + 8.0), 2.2, dot_color)
    var board := Rect2(w * 0.37, top + h * 0.018, w * 0.26, h * 0.105)
    draw_rect(board, Color("092340", 0.90), true)
    draw_rect(board, Color("8fd6ed", 0.58), false, 2.0)
    for column in range(1, 6):
        var x := board.position.x + board.size.x * float(column) / 6.0
        draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), Color("7cbfdc", 0.28), 1.0)
    for row in range(1, 3):
        var y := board.position.y + board.size.y * float(row) / 3.0
        draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), Color("7cbfdc", 0.28), 1.0)
    for light in range(8):
        var lx := board.position.x + 10.0 + float(light) * (board.size.x - 20.0) / 7.0
        draw_circle(Vector2(lx, board.position.y + 8.0), 2.0, Color("ffd66b", 0.9))
    draw_rect(Rect2(0.0, h * 0.43, w, 5.0), Color("8be1ce", 0.52))
    for side in [-1.0, 1.0]:
        var x := w * (0.055 if side < 0.0 else 0.945)
        draw_line(Vector2(x, h * 0.06), Vector2(x + side * 25.0, h * 0.30), Color(0.08, 0.17, 0.30, 0.84), 4.0)
        for light in range(5):
            var lx: float = x + float(side) * float(light) * 5.0
            var ly: float = h * 0.08 + float(light % 2) * 3.0
            draw_circle(Vector2(lx, ly), 3.4, Color(1.0, 0.97, 0.76, 0.95))
            draw_circle(Vector2(lx, ly), 10.0, Color(1.0, 0.90, 0.50, 0.10))

func _draw_field(w: float, h: float) -> void:
    var field_top := h * 0.40
    var field_points := PackedVector2Array([
        Vector2(-w * 0.08, field_top), Vector2(w * 1.08, field_top), Vector2(w * 1.16, h * 1.08), Vector2(-w * 0.16, h * 1.08)
    ])
    draw_colored_polygon(field_points, GRASS)
    for stripe in range(7):
        var left := -w * 0.18 + float(stripe) * w * 0.22
        var stripe_points := PackedVector2Array([
            Vector2(left, field_top), Vector2(left + w * 0.12, field_top), Vector2(left + w * 0.28, h * 1.08), Vector2(left + w * 0.12, h * 1.08)
        ])
        draw_colored_polygon(stripe_points, Color(GRASS_LIGHT, 0.10))
    draw_arc(Vector2(w * 0.5, h * 0.5), w * 0.52, PI, TAU, 40, Color("4cc0a1", 0.45), 3.0)
    draw_line(Vector2(w * 0.08, h * 0.46), Vector2(w * 0.92, h * 0.46), Color("124e4c"), 28.0)
    draw_line(Vector2(w * 0.08, h * 0.447), Vector2(w * 0.92, h * 0.447), Color("7fe0a2", 0.36), 3.0)
    _draw_ellipse(Vector2(w * 0.5, h * 0.70), Vector2(w * 0.255, h * 0.31), DIRT)
    _draw_ellipse(Vector2(w * 0.5, h * 0.68), Vector2(w * 0.195, h * 0.225), Color(DIRT.lightened(0.09), 0.95))
    _draw_ellipse(Vector2(w * 0.5, h * 0.55), Vector2(w * 0.058, h * 0.030), Color("dfaa68"))
    draw_line(Vector2(w * 0.5, h * 0.93), Vector2(w * 0.02, h * 0.49), LINE, 2.0)
    draw_line(Vector2(w * 0.5, h * 0.93), Vector2(w * 0.98, h * 0.49), LINE, 2.0)
    _draw_base(Vector2(w * 0.70, h * 0.68), bases[0])
    _draw_base(Vector2(w * 0.5, h * 0.51), bases[1])
    _draw_base(Vector2(w * 0.30, h * 0.68), bases[2])
    _draw_home(Vector2(w * 0.5, h * 0.93))

func _draw_field_overlay(w: float, h: float) -> void:
    # The generated background supplies the detailed grass, mound, and plate.
    # Keep only a light gameplay layer above it so the bases remain readable and
    # still react to the live runner state.
    var line_color := Color(1.0, 1.0, 0.96, 0.72)
    draw_line(Vector2(w * 0.5, h * 0.93), Vector2(w * 0.02, h * 0.49), line_color, 2.0)
    draw_line(Vector2(w * 0.5, h * 0.93), Vector2(w * 0.98, h * 0.49), line_color, 2.0)
    draw_arc(Vector2(w * 0.5, h * 0.55), w * 0.058, 0.0, TAU, 28, Color(1.0, 0.77, 0.35, 0.30), 2.0)
    _draw_base(Vector2(w * 0.70, h * 0.68), bases[0])
    _draw_base(Vector2(w * 0.5, h * 0.51), bases[1])
    _draw_base(Vector2(w * 0.30, h * 0.68), bases[2])
    _draw_home(Vector2(w * 0.5, h * 0.93))

func _draw_base(center: Vector2, occupied: bool) -> void:
    var color := Color("ffbd4b") if occupied else WHITE
    var points := PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)])
    draw_colored_polygon(points, color)
    if occupied:
        draw_arc(center, 13.0, 0.0, TAU, 24, Color(1.0, 0.78, 0.25, 0.45), 2.0)

func _draw_home(center: Vector2) -> void:
    var points := PackedVector2Array([center + Vector2(-9, -5), center + Vector2(9, -5), center + Vector2(7, 7), center + Vector2(0, 11), center + Vector2(-7, 7)])
    draw_colored_polygon(points, WHITE)

func _draw_characters(w: float, h: float) -> void:
    if pitcher_texture:
        _draw_texture_character(pitcher_texture, Vector2(w * 0.25, h * 0.60), h * 0.60)
    else:
        _draw_cat(Vector2(w * 0.24, h * 0.53), 0.92, Color("dff1ff"), Color("236fc4"), false)
    if catcher_texture:
        _draw_texture_character(catcher_texture, Vector2(w * 0.50, h * 0.68), h * 0.39)
    else:
        _draw_catcher(Vector2(w * 0.50, h * 0.65), 0.68)
    if batter_texture:
        _draw_texture_character(batter_texture, Vector2(w * 0.77, h * 0.70), h * 0.68)
    else:
        _draw_cat(Vector2(w * 0.75, h * 0.70), 1.16, Color("fff0df"), Color("ed7837"), true)

func _draw_texture_character(texture: Texture2D, center: Vector2, target_height: float) -> void:
    var source_size := texture.get_size()
    if source_size.y <= 0.0:
        return
    var target_size := Vector2(target_height * source_size.x / source_size.y, target_height)
    var rect := Rect2(center - target_size * 0.5, target_size)
    draw_ellipse_shadow(Vector2(center.x, rect.end.y - target_size.y * 0.035), target_size.x * 0.27, target_size.y * 0.025)
    draw_texture_rect(texture, rect, false)

func draw_ellipse_shadow(center: Vector2, radius_x: float, radius_y: float) -> void:
    _draw_ellipse(center, Vector2(radius_x, radius_y), Color(0.02, 0.08, 0.15, 0.24))

func _draw_cat(center: Vector2, scale: float, body_color: Color, accent: Color, batter: bool) -> void:
    var s := scale
    _draw_ellipse(center + Vector2(0, 53) * s, Vector2(38, 8) * s, Color(0.01, 0.08, 0.12, 0.34))
    _draw_ellipse(center + Vector2(0, 23) * s, Vector2(28, 43) * s, body_color)
    _draw_ellipse(center + Vector2(-12, 62) * s, Vector2(10, 16) * s, body_color.darkened(0.04))
    _draw_ellipse(center + Vector2(12, 62) * s, Vector2(10, 16) * s, body_color.darkened(0.04))
    _draw_ellipse(center + Vector2(0, -29) * s, Vector2(36, 32) * s, body_color)
    var left_ear := PackedVector2Array([center + Vector2(-30, -51) * s, center + Vector2(-20, -83) * s, center + Vector2(-5, -55) * s])
    var right_ear := PackedVector2Array([center + Vector2(30, -51) * s, center + Vector2(20, -83) * s, center + Vector2(5, -55) * s])
    draw_colored_polygon(left_ear, body_color)
    draw_colored_polygon(right_ear, body_color)
    draw_polyline(PackedVector2Array([left_ear[0], left_ear[1], left_ear[2]]), NAVY, 2.4)
    draw_polyline(PackedVector2Array([right_ear[0], right_ear[1], right_ear[2]]), NAVY, 2.4)
    _draw_ellipse(center + Vector2(-19, -62) * s, Vector2(8, 13) * s, Color("f2a9ad"))
    _draw_ellipse(center + Vector2(19, -62) * s, Vector2(8, 13) * s, Color("f2a9ad"))
    _draw_ellipse(center + Vector2(-13, -30) * s, Vector2(5, 8) * s, NAVY)
    _draw_ellipse(center + Vector2(13, -30) * s, Vector2(5, 8) * s, NAVY)
    draw_circle(center + Vector2(-11, -33) * s, 1.7 * s, WHITE)
    draw_circle(center + Vector2(15, -33) * s, 1.7 * s, WHITE)
    _draw_ellipse(center + Vector2(0, -18) * s, Vector2(4, 3) * s, Color("ef8991"))
    _draw_ellipse(center + Vector2(0, -61) * s, Vector2(37, 12) * s, accent)
    draw_line(center + Vector2(-40, -57) * s, center + Vector2(11, -58) * s, NAVY, 4.0 * s)
    draw_line(center + Vector2(-21, 8) * s, center + Vector2(21, 8) * s, accent.darkened(0.28), 3.0 * s)
    draw_line(center + Vector2(-17, 17) * s, center + Vector2(17, 17) * s, Color(1.0, 1.0, 1.0, 0.34), 2.0 * s)
    draw_circle(center + Vector2(0, 28) * s, 3.0 * s, Color(1.0, 0.96, 0.84, 0.88))
    var number_color := accent.darkened(0.25) if not batter else accent.darkened(0.35)
    _draw_ellipse(center + Vector2(0, 20) * s, Vector2(8, 12) * s, Color(number_color, 0.9))
    _draw_ellipse(center + Vector2(-28, 16) * s, Vector2(10, 22) * s, body_color)
    _draw_ellipse(center + Vector2(28, 4) * s, Vector2(10, 22) * s, body_color)
    if batter:
        draw_line(center + Vector2(24, 6) * s, center + Vector2(58, -80) * s, Color("5b351e"), 9.0 * s)
        draw_line(center + Vector2(24, 6) * s, center + Vector2(58, -80) * s, Color("d49a55"), 5.0 * s)
        draw_line(center + Vector2(-28, 20) * s, center + Vector2(-42, 47) * s, body_color, 8.0 * s)
        draw_line(center + Vector2(28, 16) * s, center + Vector2(40, 40) * s, body_color, 8.0 * s)
    else:
        draw_line(center + Vector2(-27, 19) * s, center + Vector2(-45, 36) * s, body_color, 8.0 * s)
        draw_circle(center + Vector2(-47, 37) * s, 6.0 * s, WHITE)

func _draw_catcher(center: Vector2, scale: float) -> void:
    var s := scale
    _draw_ellipse(center + Vector2(0, 28) * s, Vector2(28, 7) * s, Color(0.01, 0.08, 0.12, 0.32))
    _draw_ellipse(center + Vector2(0, 5) * s, Vector2(27, 35) * s, Color("47708e"))
    _draw_ellipse(center + Vector2(0, -34) * s, Vector2(22, 23) * s, Color("26384c"))
    draw_arc(center + Vector2(0, -34) * s, 22 * s, PI, TAU, 20, Color("102840"), 5 * s)
    draw_line(center + Vector2(-16, -34) * s, center + Vector2(16, -34) * s, Color("9ed9e7", 0.7), 2.0 * s)
    _draw_ellipse(center + Vector2(-27, 6) * s, Vector2(12, 13) * s, Color("d49555"))
    draw_circle(center + Vector2(-26, 5) * s, 4.0 * s, Color("f2c279"))

func _draw_strike_zone(w: float, h: float) -> void:
    var zone_size := Vector2(minf(154.0, w * 0.20), minf(182.0, h * 0.34))
    var zone_rect := Rect2(Vector2(w * 0.5, h * 0.68) - zone_size * 0.5, zone_size)
    draw_rect(zone_rect, Color(0.82, 0.95, 1.0, 0.10), true)
    draw_rect(zone_rect, Color(0.98, 1.0, 0.95, 0.94), false, 3.0)
    for row in range(1, 3):
        var y := zone_rect.position.y + zone_rect.size.y * float(row) / 3.0
        draw_line(Vector2(zone_rect.position.x, y), Vector2(zone_rect.end.x, y), Color(0.96, 1.0, 0.96, 0.36), 1.0)
    for col in range(1, 3):
        var x := zone_rect.position.x + zone_rect.size.x * float(col) / 3.0
        draw_line(Vector2(x, zone_rect.position.y), Vector2(x, zone_rect.end.y), Color(0.96, 1.0, 0.96, 0.36), 1.0)
    var aim_center := zone_rect.position + Vector2((float(aim_zone % 3) + 0.5) / 3.0, (float(aim_zone / 3) + 0.5) / 3.0) * zone_rect.size
    draw_arc(aim_center, minf(19.0, zone_size.x * 0.14), 0.0, TAU, 28, Color("5ad8ff"), 3.0)
    draw_circle(aim_center, 4.0, Color(0.35, 0.86, 1.0, 0.42))
    if mode == "pitch" or mode == "plate":
        var target_index := maxi(pitch_zone, 0)
        var target_center := zone_rect.position + Vector2((float(target_index % 3) + 0.5) / 3.0, (float(target_index / 3) + 0.5) / 3.0) * zone_rect.size
        if pitch_zone < 0:
            target_center = Vector2(w * 0.58, h * 0.70)
        draw_circle(target_center, 7.0, Color("ffd36b"))
        draw_arc(target_center, 13.0, 0.0, TAU, 20, Color(1.0, 0.86, 0.40, 0.72), 2.0)

func _draw_ball(w: float, h: float) -> void:
    if mode == "idle":
        return
    var position := _ball_position(w, h)
    var progress := get_pitch_progress()
    var radius := 5.0 + 8.0 * progress if mode == "pitch" or mode == "plate" else maxf(2.5, 12.0 * (1.0 - hit_elapsed * 0.8))
    if mode == "pitch" or mode == "plate":
        var trail_start := _ball_position(w, h)
        var trail_end := trail_start - Vector2(w * 0.035, h * 0.025)
        draw_line(trail_start, trail_end, Color(1.0, 1.0, 1.0, 0.28), maxf(1.0, radius * 0.16))
    draw_circle(position, radius + 3.0, Color(1.0, 1.0, 1.0, 0.16))
    draw_circle(position, radius, WHITE)
    draw_arc(position, radius * 0.72, -1.1, 1.45, 14, Color("e77676"), maxf(1.0, radius * 0.18))
    draw_arc(position, radius * 0.72, 2.0, 4.5, 14, Color("e77676"), maxf(1.0, radius * 0.18))

func _ball_position(w: float, h: float) -> Vector2:
    if mode == "hit":
        var t := clampf(hit_elapsed / 0.95, 0.0, 1.0)
        var start := Vector2(w * 0.5, h * 0.68)
        var end := Vector2(w * hit_target.x, h * hit_target.y)
        var control := Vector2(w * 0.61, h * 0.18)
        return _quadratic(start, control, end, t)
    var t := clampf(pitch_elapsed / pitch_duration, 0.0, 1.0)
    var start := Vector2(w * 0.28, h * 0.55)
    var end := Vector2(w * 0.5, h * 0.68)
    var bend := 0.0
    if pitch_kind == "curveball": bend = -w * 0.10
    elif pitch_kind == "slider": bend = w * 0.08
    elif pitch_kind == "changeup": bend = -w * 0.035
    var control := Vector2(w * 0.42 + bend, h * 0.48)
    return _quadratic(start, control, end, t)

func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
    var one_minus := 1.0 - t
    return one_minus * one_minus * a + 2.0 * one_minus * t * b + t * t * c

func _draw_impact(w: float, h: float) -> void:
    var center := Vector2(w * 0.5, h * 0.68)
    var strength := flash_time / 0.55
    draw_arc(center, 18.0 + (1.0 - strength) * 38.0, 0.0, TAU, 30, Color(1.0, 0.86, 0.39, strength), 3.0)
    for ray in range(8):
        var angle := float(ray) * TAU / 8.0
        var inner := center + Vector2.from_angle(angle) * 12.0
        var outer := center + Vector2.from_angle(angle) * (25.0 + (1.0 - strength) * 20.0)
        draw_line(inner, outer, Color(1.0, 0.9, 0.48, strength), 2.0)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(32):
        var angle := TAU * float(index) / 32.0
        points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
    draw_colored_polygon(points, color)
