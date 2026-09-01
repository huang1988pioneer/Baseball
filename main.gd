extends Control
## 喵喵棒球 · 2D Baseball Lab
## Godot 4 playable prototype:
## pitch -> read the zone -> swing on timing -> resolve contact -> score.

const PITCH_BUTTONS := [
    ["fastball", "⚾  快速球", "145 km/h"],
    ["curveball", "◒  曲球", "118 km/h"],
    ["slider", "◉  滑球", "126 km/h"],
    ["changeup", "◌  變速球", "108 km/h"]
]

const BG := Color("12345b")
const PANEL := Color(0.985, 0.995, 1.0, 0.97)
const PANEL_2 := Color(0.90, 0.95, 1.0, 0.96)
const BORDER := Color(0.10, 0.36, 0.72, 0.34)
const TEXT := Color("17385f")
const MUTED := Color("607d9d")
const BLUE := Color("1e64c8")
const GOLD := Color("f5a623")
const GREEN := Color("21a773")
const RED := Color("df5c5b")

@onready var stadium: Control = $StadiumView

var session := GameSession.new()
var sound_on := true
var coach_index := 0
var resolution_token := 0
var auto_pitch_token := 0
var cpu_swing_token := 0
var pending_character := ""
var pending_team := ""

var away_inning_cells: Array[Label] = []
var home_inning_cells: Array[Label] = []
var pitch_buttons: Dictionary = {}
var aim_buttons: Array[Button] = []

var inning_label: Label
var half_badge_label: Label
var player_score_label: Label
var rival_score_label: Label
var away_score_label: Label
var home_score_label: Label
var player_team_name_label: Label
var player_team_sub_label: Label
var rival_team_name_label: Label
var rival_team_sub_label: Label
var away_team_name_label: Label
var home_team_name_label: Label
var away_team_sub_label: Label
var home_team_sub_label: Label
var away_tag_label: Label
var home_tag_label: Label
var player_crest: TextureRect
var rival_crest: TextureRect
var away_crest: TextureRect
var home_crest: TextureRect
var controls_label: Label
var controls_hint_label: Label
var setup_overlay: Control
var setup_start_button: Button
var setup_summary: Label
var setup_character_buttons: Dictionary = {}
var setup_team_buttons: Dictionary = {}
var ball_count_label: Label
var strike_count_label: Label
var out_count_label: Label
var at_bat_label: Label
var hero_combo_label: Label
var pitch_readout_label: Label
var pitch_speed_label: Label
var timing_bar: ProgressBar
var status_kicker: Label
var status_title: Label
var status_sub: Label
var burst_label: Label
var mission_perfect_label: Label
var mission_hits_label: Label
var mission_runs_label: Label
var batter_state_label: Label
var coach_note_label: Label
var pitch_button: Button
var swing_button: Button
var sound_button: Button
var tutorial: AcceptDialog
var toast_label: Label
var toast_tween: Tween
var toast_token := 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_interface()
    _build_setup_overlay()
    if stadium.has_signal("pitch_arrived"):
        stadium.pitch_arrived.connect(_on_pitch_arrived)
    _select_pitch("fastball")
    _select_aim(4)
    _update_ui()
    _set_message("LINEUP", "先選角色與球隊", "選好後再開始比賽")
    set_process(false)
    _show_setup()

func _process(_delta: float) -> void:
    if not session.is_live_pitch():
        timing_bar.value = 0.0
        set_process(false)
        return
    var progress: float = float(stadium.get_pitch_progress())
    timing_bar.value = minf(100.0, progress * 100.0)
    pitch_speed_label.text = str(session.active_pitch.get("speed", 0)) + " km/h · 球進壘中"

func _build_interface() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.color = Color("e8f4ff")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 12)
    add_child(margin)

    var content := VBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)

    content.add_child(_build_topbar())

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    content.add_child(body)

    var game_column := VBoxContainer.new()
    game_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    game_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    game_column.add_theme_constant_override("separation", 8)
    body.add_child(game_column)

    var scoreboard := _build_scoreboard()
    game_column.add_child(scoreboard)

    var stadium_panel := _build_stadium_panel()
    stadium_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    game_column.add_child(stadium_panel)
    game_column.add_child(_build_controls())

    var extras := VBoxContainer.new()
    extras.visible = false
    extras.add_child(_build_hero())
    extras.add_child(_build_feature_card())
    extras.add_child(_build_mission_card())
    extras.add_child(_build_lineup_card())
    extras.add_child(_build_character_gallery())
    extras.add_child(_build_coach_card())
    extras.add_child(_build_shortcut_card())
    extras.add_child(_build_design_notes())
    extras.add_child(_build_footer())
    add_child(extras)

    tutorial = AcceptDialog.new()
    tutorial.title = "怎麼玩 · 喵喵棒球"
    tutorial.dialog_text = "1. 客隊先攻、主隊後攻。三出局後攻守轉換。\n2. 打擊時：投手會在 3–15 秒內自動投球，靠近本壘再揮棒。\n3. 守備時：自己選球路投球，對手會自動揮棒。\n\n三個好球出局，四個壞球保送。"
    tutorial.ok_button_text = "知道了，開始第一球"
    tutorial.min_size = Vector2(480, 260)
    add_child(tutorial)

    toast_label = _label("", 12, TEXT)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.visible = false
    toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    toast_label.position = Vector2(-220, -58)
    toast_label.size = Vector2(440, 38)
    toast_label.add_theme_stylebox_override("normal", _panel_style(Color(0.03, 0.13, 0.25, 0.97), Color(0.39, 0.75, 0.95, 0.34), 18))
    add_child(toast_label)

func _build_feature_card() -> Control:
    var panel := _make_panel(Vector2(0, 178))
    var v := _card_content(panel, 13)
    var heading := _label("遊戲特色", 13, Color("ffffff"))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    heading.custom_minimum_size = Vector2(0, 30)
    heading.add_theme_stylebox_override("normal", _panel_style(Color("246ac4"), Color("1b59ae"), 10))
    v.add_child(heading)
    var rows := [
        "可愛 2D 角色與生動動畫",
        "簡單操作，爽快打擊手感",
        "多種球路與必殺技系統",
        "養成球員，挑戰聯賽冠軍"
    ]
    for row_text in rows:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var icon := _label("✣", 14, Color("e86b3d"))
        icon.custom_minimum_size = Vector2(21, 24)
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        row.add_child(icon)
        row.add_child(_label(row_text, 10, TEXT))
        v.add_child(row)
    return panel

func _build_topbar() -> Control:
    var bar := PanelContainer.new()
    bar.custom_minimum_size = Vector2(0, 54)
    bar.add_theme_stylebox_override("panel", _panel_style(Color(0.99, 1.0, 1.0, 0.98), Color(0.13, 0.40, 0.78, 0.34), 18))
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    row.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
    var pad := _pad(row, 6, 12, 6, 12)
    bar.add_child(pad)
    var logo_texture := load("res://assets/generated/logo-v1.png") as Texture2D
    if logo_texture:
        var logo := TextureRect.new()
        logo.texture = logo_texture
        logo.custom_minimum_size = Vector2(150, 48)
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(logo)
    else:
        var brand_mark := _label("⚾", 25, BG)
        brand_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        brand_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        brand_mark.custom_minimum_size = Vector2(40, 40)
        brand_mark.add_theme_stylebox_override("normal", _panel_style(Color("ffd45f"), Color("f09a2c"), 12))
        row.add_child(brand_mark)
        var brand_text := VBoxContainer.new()
        brand_text.add_theme_constant_override("separation", 0)
        var brand := _label("喵喵棒球", 19, TEXT)
        var sub := _label("2D BASEBALL  ·  SEASON 01", 9, Color("6b8aab"))
        brand.add_theme_constant_override("outline_size", 4)
        brand_text.add_child(brand)
        brand_text.add_child(sub)
        row.add_child(brand_text)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    var combo_panel := PanelContainer.new()
    combo_panel.custom_minimum_size = Vector2(118, 40)
    combo_panel.add_theme_stylebox_override("panel", _panel_style(Color("fff6dd"), Color(0.95, 0.58, 0.10, 0.48), 12))
    var combo_row := HBoxContainer.new()
    combo_row.add_theme_constant_override("separation", 6)
    combo_panel.add_child(_pad(combo_row, 4, 8, 4, 8))
    combo_row.add_child(_label("COMBO", 8, Color("bd7a20")))
    hero_combo_label = _label("0", 18, GOLD)
    combo_row.add_child(hero_combo_label)
    row.add_child(combo_panel)
    var version := _label("LIVE MATCH  ·  3 INNINGS", 9, BLUE)
    version.custom_minimum_size = Vector2(170, 0)
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(version)
    var how := _button("✦  怎麼玩", Vector2(98, 36))
    how.pressed.connect(_open_tutorial)
    row.add_child(how)
    sound_button = _button("🔊", Vector2(38, 36))
    sound_button.tooltip_text = "切換音效"
    sound_button.pressed.connect(_toggle_sound)
    row.add_child(sound_button)
    var reset := _button("重置", Vector2(54, 36))
    reset.pressed.connect(_reset_game)
    row.add_child(reset)
    return bar

func _build_hero() -> Control:
    var hero := HBoxContainer.new()
    hero.custom_minimum_size = Vector2(0, 86)
    hero.add_theme_constant_override("separation", 20)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 4)
    var eyebrow := _label("●  LIVE MATCH  ·  BATTER UP", 10, BLUE)
    copy.add_child(eyebrow)
    var title := _label("把每一球，", 29, TEXT)
    title.text += "打成你的主場。"
    title.add_theme_color_override("font_color", TEXT)
    copy.add_child(title)
    var lede := _label("讀球路、抓節奏、揮出漂亮的安打。", 11, MUTED)
    lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.add_child(lede)
    hero.add_child(copy)
    return hero

func _build_scoreboard() -> Control:
    var panel := _make_panel(Vector2(0, 168))
    var v := _card_content(panel, 10)
    var heading := HBoxContainer.new()
    heading.add_theme_constant_override("separation", 8)
    var live := _label("●  LIVE", 9, GREEN)
    heading.add_child(live)
    half_badge_label = _label("▲  上半局", 10, Color("ffffff"))
    half_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    half_badge_label.custom_minimum_size = Vector2(86, 22)
    half_badge_label.add_theme_stylebox_override("normal", _panel_style(Color("1e64c8"), Color("1b59ae"), 9))
    heading.add_child(half_badge_label)
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(fill)
    inning_label = _label("第 1 局 · 客隊先攻", 10, Color("6583a5"))
    heading.add_child(inning_label)
    v.add_child(heading)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    var header_team := Control.new()
    header_team.custom_minimum_size = Vector2(168, 0)
    header.add_child(header_team)
    var header_strip := HBoxContainer.new()
    header_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_strip.add_theme_constant_override("separation", 1)
    for i in range(9):
        var num := _label(str(i + 1), 8, Color("8ba9c8"))
        num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        num.custom_minimum_size = Vector2(30, 16)
        header_strip.add_child(num)
    header.add_child(header_strip)
    var header_r := _label("R", 9, Color("8ba9c8"))
    header_r.custom_minimum_size = Vector2(55, 0)
    header_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(header_r)
    v.add_child(header)

    var away_built: Dictionary = _build_line_score_row("客", "喵布布隊", "AWAY CAT  ·  喵布布", "res://assets/generated/away-crest-v1.png", Color("ef7e32"))
    v.add_child(away_built["row"])
    away_crest = away_built["crest"]
    away_team_name_label = away_built["name"]
    away_team_sub_label = away_built["sub"]
    away_tag_label = away_built["tag"]
    away_inning_cells = away_built["cells"]
    away_score_label = away_built["score"]
    player_team_name_label = away_team_name_label
    player_team_sub_label = away_team_sub_label
    player_crest = away_crest
    player_score_label = away_score_label

    var home_built: Dictionary = _build_line_score_row("主", "喵白白隊", "HOME CAT  ·  喵白白", "res://assets/generated/home-crest-v1.png", BLUE)
    v.add_child(home_built["row"])
    home_crest = home_built["crest"]
    home_team_name_label = home_built["name"]
    home_team_sub_label = home_built["sub"]
    home_tag_label = home_built["tag"]
    home_inning_cells = home_built["cells"]
    home_score_label = home_built["score"]
    rival_team_name_label = home_team_name_label
    rival_team_sub_label = home_team_sub_label
    rival_crest = home_crest
    rival_score_label = home_score_label

    var count_row := HBoxContainer.new()
    count_row.add_theme_constant_override("separation", 14)
    count_row.add_theme_stylebox_override("panel", _panel_style(Color("eef6ff"), Color(0.12, 0.38, 0.72, 0.12), 8))
    ball_count_label = _label("B  ○○○○", 9, Color("2d9a67"))
    strike_count_label = _label("S  ○○○", 9, Color("e79a1d"))
    out_count_label = _label("O  ○○○", 9, Color("df5d63"))
    at_bat_label = _label("先選角色與球隊", 9, Color("617f9f"))
    count_row.add_child(ball_count_label)
    count_row.add_child(strike_count_label)
    count_row.add_child(out_count_label)
    var count_fill := Control.new()
    count_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    count_row.add_child(count_fill)
    count_row.add_child(at_bat_label)
    v.add_child(count_row)
    return panel

func _build_stadium_panel() -> Control:
    var holder := _make_panel(Vector2(0, 240))
    holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    holder.clip_contents = true
    stadium.reparent(holder)
    stadium.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stadium.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(overlay)

    var status := VBoxContainer.new()
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-220, 24)
    status.size = Vector2(440, 66)
    status.alignment = BoxContainer.ALIGNMENT_CENTER
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_kicker = _label("READY?", 10, Color("e9f6ff"))
    status_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_title = _label("先選角色與球隊", 18, Color("ffffff"))
    status_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_sub = _label("靠近本壘時按下揮棒", 10, Color("d3edff"))
    status_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_child(status_kicker)
    status.add_child(status_title)
    status.add_child(status_sub)
    overlay.add_child(status)

    burst_label = _label("", 30, GOLD)
    burst_label.set_anchors_preset(Control.PRESET_CENTER)
    burst_label.position = Vector2(-260, -100)
    burst_label.size = Vector2(520, 70)
    burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    burst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    burst_label.modulate.a = 0.0
    burst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(burst_label)

    var hud := PanelContainer.new()
    hud.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    hud.position = Vector2(-430, -64)
    hud.size = Vector2(860, 50)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.16, 0.30, 0.88), Color(0.74, 0.91, 1.0, 0.45), 12))
    var hud_row := HBoxContainer.new()
    hud_row.add_theme_constant_override("separation", 12)
    hud.add_child(_pad(hud_row, 7, 11, 7, 11))
    var readout := VBoxContainer.new()
    pitch_readout_label = _label("快速球", 13, TEXT)
    pitch_speed_label = _label("等待投球", 8, GOLD)
    readout.add_child(pitch_readout_label)
    readout.add_child(pitch_speed_label)
    hud_row.add_child(readout)
    timing_bar = ProgressBar.new()
    timing_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timing_bar.custom_minimum_size = Vector2(310, 12)
    timing_bar.show_percentage = false
    timing_bar.min_value = 0.0
    timing_bar.max_value = 100.0
    timing_bar.add_theme_stylebox_override("background", _panel_style(Color("25527a"), Color(0, 0, 0, 0), 8))
    timing_bar.add_theme_stylebox_override("fill", _panel_style(Color("78d85f"), Color(0, 0, 0, 0), 8))
    hud_row.add_child(timing_bar)
    var timing_text := _label("EARLY        PERFECT        LATE", 8, Color("c9e8ff"))
    timing_text.custom_minimum_size = Vector2(170, 0)
    timing_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_row.add_child(timing_text)
    overlay.add_child(hud)
    return holder

func _build_controls() -> Control:
    var panel := _make_panel(Vector2(0, 132))
    var v := _card_content(panel, 13)
    var heading := HBoxContainer.new()
    controls_label = _label("預判球路", 11, TEXT)
    heading.add_child(controls_label)
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(fill)
    controls_hint_label = _label("先選角色與球隊", 9, Color("6b88a9"))
    heading.add_child(controls_hint_label)
    v.add_child(heading)

    var pitch_row := HBoxContainer.new()
    pitch_row.add_theme_constant_override("separation", 7)
    for item in PITCH_BUTTONS:
        var button := _button(str(item[1]) + "\n" + str(item[2]), Vector2(0, 50))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 10)
        button.tooltip_text = "選擇" + str(item[1])
        button.pressed.connect(_on_pitch_button_pressed.bind(str(item[0])))
        pitch_buttons[str(item[0])] = button
        pitch_row.add_child(button)
    v.add_child(pitch_row)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    var aim_box := VBoxContainer.new()
    aim_box.custom_minimum_size = Vector2(148, 0)
    aim_box.add_child(_label("瞄準落點", 9, Color("6b88a9")))
    var aim_grid := GridContainer.new()
    aim_grid.columns = 3
    aim_grid.add_theme_constant_override("h_separation", 3)
    aim_grid.add_theme_constant_override("v_separation", 3)
    for i in range(9):
        var aim := _button("", Vector2(25, 18))
        aim.focus_mode = Control.FOCUS_ALL
        aim.tooltip_text = "瞄準第 " + str(i + 1) + " 格"
        aim.pressed.connect(_on_aim_button_pressed.bind(i))
        aim_buttons.append(aim)
        aim_grid.add_child(aim)
    aim_box.add_child(aim_grid)
    actions.add_child(aim_box)

    pitch_button = _button("↗  投球\nTHROW PITCH", Vector2(0, 66))
    pitch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pitch_button.add_theme_font_size_override("font_size", 13)
    pitch_button.pressed.connect(_start_pitch)
    actions.add_child(pitch_button)

    swing_button = _button("揮棒\nSWING", Vector2(0, 75))
    swing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    swing_button.add_theme_font_size_override("font_size", 14)
    var swing_texture := load("res://assets/generated/swing-badge-v1.png") as Texture2D
    if swing_texture:
        swing_button.icon = swing_texture
        swing_button.expand_icon = true
    swing_button.pressed.connect(_swing)
    actions.add_child(swing_button)
    v.add_child(actions)
    _refresh_button_styles()
    return panel

func _build_mission_card() -> Control:
    var panel := _make_panel(Vector2(0, 190))
    var v := _card_content(panel, 13)
    v.add_child(_card_heading("✦  今日任務", "第 1 / 3 局"))
    var rows := [
        ["⚡", "揮出一次 PERFECT", "抓準甜蜜點，初速 +20%"],
        ["◆", "累積 3 支安打", "連續安打會提高 COMBO"],
        ["★", "拿下 2 分", "跑者回本壘即可得分"]
    ]
    for index in range(rows.size()):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var icon := _label(str(rows[index][0]), 14, GOLD if index == 0 else BLUE if index == 1 else Color("ffad83"))
        icon.custom_minimum_size = Vector2(24, 26)
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        row.add_child(icon)
        var copy := VBoxContainer.new()
        copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        copy.add_child(_label(str(rows[index][1]), 10, TEXT))
        var detail := _label(str(rows[index][2]), 8, Color("6b88a9"))
        detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        copy.add_child(detail)
        row.add_child(copy)
        var progress := _label("0/" + ("1" if index == 0 else "3" if index == 1 else "2"), 10, GOLD)
        if index == 0: mission_perfect_label = progress
        elif index == 1: mission_hits_label = progress
        else: mission_runs_label = progress
        row.add_child(progress)
        v.add_child(row)
    return panel

func _build_lineup_card() -> Control:
    var panel := _make_panel(Vector2(0, 166))
    var v := _card_content(panel, 13)
    v.add_child(_card_heading("♟  今日先發", "陣容"))
    var data := [
        ["喵", "喵白白", "投手 · #1", "READY", Color("a5d5ff")],
        ["布", "喵布布", "打者 · #B", "ON DECK", Color("ffc185")],
        ["咪", "咪嚕", "外野 · #7", "BENCH", Color("f8b6dc")]
    ]
    for index in range(data.size()):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var avatar := _label(str(data[index][0]), 9, BG)
        avatar.custom_minimum_size = Vector2(30, 30)
        avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        avatar.add_theme_stylebox_override("normal", _panel_style(data[index][4], Color(0, 0, 0, 0), 8))
        row.add_child(avatar)
        var copy := VBoxContainer.new()
        copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        copy.add_child(_label(str(data[index][1]), 10, TEXT))
        copy.add_child(_label(str(data[index][2]), 8, Color("6b88a9")))
        row.add_child(copy)
        var state_label := _label(str(data[index][3]), 7, GREEN if index == 0 else Color("6c8cad"))
        if index == 1: batter_state_label = state_label
        row.add_child(state_label)
        v.add_child(row)
    return panel

func _build_coach_card() -> Control:
    var panel := _make_panel(Vector2(0, 182))
    panel.add_theme_stylebox_override("panel", _panel_style(Color("e5f2ff"), Color(0.15, 0.43, 0.78, 0.36), 16))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    panel.add_child(_pad(row, 14, 14, 10, 14))
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_child(_label("COACH'S NOTE", 8, BLUE))
    copy.add_child(_label("球來就看，\n甜蜜點再揮。", 19, TEXT))
    coach_note_label = _label(GameRules.COACH_NOTES[0], 8, Color("6b88a9"))
    coach_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.add_child(coach_note_label)
    var next := _button("知道了  →", Vector2(84, 27))
    next.add_theme_font_size_override("font_size", 9)
    next.pressed.connect(_next_coach_note)
    copy.add_child(next)
    row.add_child(copy)
    var texture_rect := TextureRect.new()
    texture_rect.custom_minimum_size = Vector2(125, 150)
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var coach_texture := load("res://assets/generated/coach-v2.png") as Texture2D
    if coach_texture == null:
        coach_texture = load("res://assets/coach_cat.png") as Texture2D
    if coach_texture == null:
        coach_texture = load("res://assets/coach.png") as Texture2D
    if coach_texture:
        texture_rect.texture = coach_texture
    row.add_child(texture_rect)
    return panel

func _build_character_gallery() -> Control:
    var panel := _make_panel(Vector2(0, 166))
    var v := _card_content(panel, 11)
    v.add_child(_card_heading("✦  主角群", "NEW CAST"))
    var art := TextureRect.new()
    art.custom_minimum_size = Vector2(0, 108)
    art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.texture = load("res://assets/generated/character-cards-v1.png") as Texture2D
    v.add_child(art)
    var meta := HBoxContainer.new()
    meta.alignment = BoxContainer.ALIGNMENT_CENTER
    meta.add_theme_constant_override("separation", 6)
    var labels := _label("教練  ·  投手  ·  打者  ·  捕手", 8, Color("6b88a9"))
    labels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    meta.add_child(labels)
    var crest := TextureRect.new()
    crest.custom_minimum_size = Vector2(24, 24)
    crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    crest.texture = load("res://assets/generated/league-crest-v1.png") as Texture2D
    crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meta.add_child(crest)
    v.add_child(meta)
    return panel

func _build_shortcut_card() -> Control:
    var panel := _make_panel(Vector2(0, 61))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 9)
    panel.add_child(_pad(row, 10, 12, 10, 12))
    var key := _label("?", 13, BLUE)
    key.custom_minimum_size = Vector2(27, 27)
    key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    key.add_theme_stylebox_override("normal", _panel_style(Color("e3f0ff"), BORDER, 7))
    row.add_child(key)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_child(_label("需要提示？", 10, TEXT))
    copy.add_child(_label("開啟新手教學，30 秒掌握節奏", 8, Color("6b88a9")))
    row.add_child(copy)
    var help := _button("↗", Vector2(28, 28))
    help.pressed.connect(_open_tutorial)
    row.add_child(help)
    return panel

func _build_design_notes() -> Control:
    var wrap := VBoxContainer.new()
    wrap.add_theme_constant_override("separation", 7)
    var kicker := _label("FROM IDEA TO PLAYABLE LOOP", 9, BLUE)
    wrap.add_child(kicker)
    var title := _label("先做核心手感，再長出完整球賽。", 25, TEXT)
    wrap.add_child(title)
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    var cards := [
        ["01", "⚾  球路系統", "快速球、曲球、滑球與變速球各有不同節奏，先猜球再調整瞄準。", "Pitching  ·  Trajectory", "res://assets/generated/pitch-system-v1.png"],
        ["02", "✦  打擊判定", "在 Timing Window 抓到綠色甜蜜點，Perfect 會帶來更高的長打機率。", "Early  ·  Good  ·  Perfect", "res://assets/generated/timing-system-v1.png"],
        ["03", "↗  擊球結果", "從一壘安打到全壘打，跑者推進、界外球與守備接殺都會改變回合。", "Contact  ·  Result  ·  Defense", "res://assets/generated/hit-results-v1.png"],
        ["04", "★  養成與模式", "先用 3 局原型建立手感，再接上球員能力、技能與聯賽挑戰。", "Growth  ·  Skills  ·  League", "res://assets/generated/player-card-v1.png"]
    ]
    for item in cards:
        var card := _make_panel(Vector2(0, 310))
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var cv := _card_content(card, 16)
        cv.add_child(_label(str(item[0]), 9, Color("6b88a9")))
        var art := TextureRect.new()
        art.custom_minimum_size = Vector2(0, 126)
        art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var art_texture := load(str(item[4])) as Texture2D
        if art_texture:
            art.texture = art_texture
        cv.add_child(art)
        cv.add_child(_label(str(item[1]), 16, TEXT))
        var desc := _label(str(item[2]), 10, Color("6b88a9"))
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        cv.add_child(desc)
        cv.add_child(_label(str(item[3]), 8, BLUE))
        row.add_child(card)
    wrap.add_child(row)
    return wrap

func _build_footer() -> Control:
    var footer := HBoxContainer.new()
    footer.custom_minimum_size = Vector2(0, 26)
    var left := _label("喵喵棒球 · Godot 4 Prototype", 9, Color("6b88a9"))
    footer.add_child(left)
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(fill)
    footer.add_child(_label("用一球的時間，測試一個好點子。", 9, Color("6b88a9")))
    return footer

func _build_setup_overlay() -> void:
    setup_overlay = Control.new()
    setup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    setup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    setup_overlay.z_index = 80
    add_child(setup_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.05, 0.11, 0.78)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    setup_overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    setup_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 0)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("10284c"), Color(0.45, 0.78, 1.0, 0.38), 20))
    center.add_child(panel)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 14)
    panel.add_child(_pad(body, 22, 24, 22, 24))

    var kicker := _label("PREMATCH  ·  先選再打", 9, Color("7dd2ff"))
    body.add_child(kicker)
    var title := _label("選擇角色與球隊", 26, Color("f3f9ff"))
    body.add_child(title)
    var lede := _label("客隊先攻、主隊後攻。三出局後攻守轉換：打擊時投手 3–15 秒自動投球，守備時對手自動揮棒。", 11, Color("9bb8d6"))
    lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(lede)

    body.add_child(_label("角色", 11, Color("d7ecff")))
    var character_row := HBoxContainer.new()
    character_row.add_theme_constant_override("separation", 10)
    body.add_child(character_row)
    for character_id in GameRules.CHARACTER_ORDER:
        var character: Dictionary = GameRules.CHARACTERS[character_id]
        var card := _setup_choice_card()
        card.custom_minimum_size = Vector2(0, 228)
        card.gui_input.connect(_on_setup_character_gui.bind(str(character_id)))
        var card_body := VBoxContainer.new()
        card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_body.add_theme_constant_override("separation", 6)
        var character_pad := _pad(card_body, 10, 10, 10, 10)
        character_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(character_pad)
        var art := TextureRect.new()
        art.custom_minimum_size = Vector2(0, 108)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art.texture = load(GameRules.art_path(str(character["art"]))) as Texture2D
        card_body.add_child(art)
        var name_label := _label(str(character["name"]), 13, Color("17385f"))
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        card_body.add_child(name_label)
        var role_label := _label(str(character["role_label"]) + "  ·  " + str(character["number"]), 9, Color("1e64c8"))
        role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        card_body.add_child(role_label)
        var blurb := _label(str(character["blurb"]), 8, Color("607d9d"))
        blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        card_body.add_child(blurb)
        character_row.add_child(card)
        setup_character_buttons[str(character_id)] = card

    body.add_child(_label("球隊", 11, Color("d7ecff")))
    var team_row := HBoxContainer.new()
    team_row.add_theme_constant_override("separation", 10)
    body.add_child(team_row)
    for team_id in GameRules.TEAM_ORDER:
        var team: Dictionary = GameRules.TEAMS[team_id]
        var card := _setup_choice_card()
        card.custom_minimum_size = Vector2(0, 72)
        card.gui_input.connect(_on_setup_team_gui.bind(str(team_id)))
        var row := HBoxContainer.new()
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 10)
        var team_pad := _pad(row, 10, 12, 10, 12)
        team_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(team_pad)
        row.add_child(_team_icon(GameRules.art_path(str(team["art"]))))
        var copy := VBoxContainer.new()
        copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
        copy.add_child(_label(str(team["name"]), 14, Color("17385f")))
        copy.add_child(_label(str(team["short"]), 8, Color("607d9d")))
        row.add_child(copy)
        team_row.add_child(card)
        setup_team_buttons[str(team_id)] = card

    setup_summary = _label("請先點選角色與球隊。", 10, Color("c9e6ff"))
    body.add_child(setup_summary)
    setup_start_button = _button("開始比賽", Vector2(0, 44))
    setup_start_button.add_theme_font_size_override("font_size", 14)
    setup_start_button.disabled = true
    setup_start_button.pressed.connect(_start_match)
    body.add_child(setup_start_button)
    _refresh_setup_styles()

    if toast_label:
        toast_label.z_index = 90

func _setup_choice_card() -> PanelContainer:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return card

func _on_setup_character_gui(event: InputEvent, character_id: String) -> void:
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
            _on_setup_character_pressed(character_id)

func _on_setup_team_gui(event: InputEvent, team_id: String) -> void:
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
            _on_setup_team_pressed(team_id)

func _make_panel(min_size: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = min_size
    panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 14))
    return panel

func _build_line_score_row(side: String, name: String, sub: String, crest_path: String, total_color: Color) -> Dictionary:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var team_box := VBoxContainer.new()
    team_box.custom_minimum_size = Vector2(168, 0)
    team_box.add_theme_constant_override("separation", 2)
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 6)
    var tag := _label(side, 8, Color("ffffff"))
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tag.custom_minimum_size = Vector2(22, 18)
    tag.add_theme_stylebox_override("normal", _panel_style(Color("246ac4") if side == "主" else Color("ef7e32"), Color(0, 0, 0, 0), 6))
    head.add_child(tag)
    var crest := _team_icon(crest_path)
    head.add_child(crest)
    var name_label := _label(name, 12, TEXT)
    head.add_child(name_label)
    team_box.add_child(head)
    var sub_label := _label(sub, 8, Color("6f8baa"))
    team_box.add_child(sub_label)
    row.add_child(team_box)
    var strip := HBoxContainer.new()
    strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    strip.add_theme_constant_override("separation", 1)
    var cells: Array[Label] = []
    for i in range(9):
        var cell := _label("—", 11, Color("5f7ea2"))
        cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cell.custom_minimum_size = Vector2(30, 28)
        cell.add_theme_stylebox_override("normal", _panel_style(Color("edf5ff"), Color(0.15, 0.39, 0.70, 0.18), 5))
        strip.add_child(cell)
        cells.append(cell)
    row.add_child(strip)
    var total := _label("0", 21, total_color)
    total.custom_minimum_size = Vector2(55, 0)
    total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(total)
    return {
        "row": row,
        "crest": crest,
        "name": name_label,
        "sub": sub_label,
        "tag": tag,
        "cells": cells,
        "score": total
    }

func _card_content(panel: Control, padding: int) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(_pad(v, padding, padding, padding, padding))
    return v

func _card_heading(title: String, meta: String) -> Control:
    var row := HBoxContainer.new()
    var heading := _label(title, 11, Color("ffffff"))
    heading.custom_minimum_size = Vector2(110, 28)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_stylebox_override("normal", _panel_style(Color("246ac4"), Color("1b59ae"), 9))
    row.add_child(heading)
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(fill)
    row.add_child(_label(meta, 8, Color("6b88a9")))
    return row

func _pad(child: Control, top: int, left: int, bottom: int, right: int) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_top", top)
    margin.add_theme_constant_override("margin_left", left)
    margin.add_theme_constant_override("margin_bottom", bottom)
    margin.add_theme_constant_override("margin_right", right)
    margin.add_child(child)
    return margin

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label

func _team_icon(path: String) -> TextureRect:
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(28, 28)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture = load(path) as Texture2D
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return icon

func _button(text: String, min_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = min_size
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", BLUE)
    button.add_theme_color_override("font_pressed_color", TEXT)
    button.add_theme_color_override("font_disabled_color", Color("8ca2bc"))
    button.add_theme_stylebox_override("normal", _button_style(Color("f3f7fc"), Color(0.14, 0.38, 0.70, 0.22), 9))
    button.add_theme_stylebox_override("hover", _button_style(Color("e4f3ff"), Color("2f82dd"), 9))
    button.add_theme_stylebox_override("pressed", _button_style(Color("cce5ff"), Color("1d62ba"), 9))
    button.add_theme_stylebox_override("disabled", _button_style(Color("e5ebf2"), Color(0.20, 0.35, 0.55, 0.14), 9))
    return button

func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    style.shadow_color = Color(0.08, 0.25, 0.52, 0.14)
    style.shadow_size = 7
    style.anti_aliasing = true
    return style

func _button_style(bg: Color, border: Color, radius: int = 9) -> StyleBoxFlat:
    var style := _panel_style(bg, border, radius)
    style.content_margin_left = 9
    style.content_margin_right = 9
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _refresh_button_styles() -> void:
    for name in pitch_buttons:
        var button: Button = pitch_buttons[name]
        var selected: bool = str(name) == session.selected_pitch
        button.add_theme_color_override("font_color", TEXT)
        button.add_theme_color_override("font_hover_color", TEXT)
        button.add_theme_color_override("font_pressed_color", TEXT)
        button.add_theme_stylebox_override("normal", _button_style(Color("dceeff") if selected else Color("f4f8fd"), Color("2f76cf") if selected else Color(0.14, 0.38, 0.70, 0.20), 11))
        button.add_theme_stylebox_override("hover", _button_style(Color("e8f5ff"), Color("2f76cf"), 11))
        button.add_theme_stylebox_override("pressed", _button_style(Color("c4e1ff"), Color("1d62ba"), 11))
        button.add_theme_stylebox_override("disabled", _button_style(Color("e5ebf2"), Color(0.20, 0.35, 0.55, 0.14), 11))
    if pitch_button:
        pitch_button.add_theme_color_override("font_color", Color("ffffff"))
        pitch_button.add_theme_color_override("font_hover_color", Color("ffffff"))
        pitch_button.add_theme_stylebox_override("normal", _button_style(Color("2b70c9"), Color("74bbff"), 13))
        pitch_button.add_theme_stylebox_override("hover", _button_style(Color("3e86df"), Color("b5e1ff"), 13))
        pitch_button.add_theme_stylebox_override("disabled", _button_style(Color("87a8cc"), Color(0.20, 0.35, 0.55, 0.2), 13))
    if swing_button:
        swing_button.add_theme_stylebox_override("normal", _button_style(Color(0.97, 0.55, 0.14, 1.0), Color("ffdf78"), 18))
        swing_button.add_theme_color_override("font_color", BG)
        swing_button.add_theme_color_override("font_hover_color", BG)
        swing_button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.67, 0.23, 1.0), Color("fff0a5"), 18))
        swing_button.add_theme_stylebox_override("pressed", _button_style(Color(0.92, 0.43, 0.10, 1.0), Color("ffcf5e"), 18))
        swing_button.add_theme_stylebox_override("disabled", _button_style(Color(0.32, 0.25, 0.16, 0.55), Color(0.5, 0.4, 0.25, 0.2), 18))

func _on_pitch_button_pressed(name: String) -> void:
    if session.can_choose():
        _select_pitch(name)

func _select_pitch(name: String) -> void:
    if not session.select_pitch(name):
        return
    var definition: Dictionary = session.pitch_definition()
    if pitch_readout_label:
        pitch_readout_label.text = str(definition["label"])
        pitch_speed_label.text = str(definition["speed"]) + " km/h 預測"
    _refresh_button_styles()

func _on_aim_button_pressed(index: int) -> void:
    if session.can_choose():
        _select_aim(index)

func _select_aim(index: int) -> void:
    session.select_aim(index)
    if stadium.has_method("set_aim_zone"):
        stadium.set_aim_zone(session.aim_zone)
    for i in range(aim_buttons.size()):
        var selected := i == session.aim_zone
        aim_buttons[i].add_theme_stylebox_override("normal", _button_style(Color("3f8ee0") if selected else Color("edf4fb"), Color("2b76ce") if selected else Color(0.14, 0.38, 0.70, 0.25), 3))
        aim_buttons[i].add_theme_stylebox_override("hover", _button_style(Color("bfe3ff"), Color("2f82dd"), 3))

func _start_pitch() -> void:
    if not session.match_ready:
        return
    var started: Dictionary = session.start_pitch()
    if started.get("restart", false):
        _reset_game()
        return
    if not started.get("ok", false):
        return
    auto_pitch_token += 1
    set_process(true)
    if stadium.has_method("start_pitch"):
        stadium.start_pitch(float(started["duration"]), str(started["kind"]), int(started["zone"]))
    _set_controls_disabled(true)
    if session.is_player_offense():
        swing_button.disabled = false
        _set_message("WATCH THE BALL", "準備揮棒！", "球越靠近本壘，Timing 越漂亮")
    else:
        _set_message("THE PITCH", "球已出手", "對手會自動打擊")
        _schedule_cpu_batter()
    pitch_readout_label.text = str(started["label"])
    pitch_speed_label.text = str(started["speed"]) + " km/h · 球進壘中"

func _on_pitch_arrived() -> void:
    var result: Dictionary = session.resolve_take()
    if not result.get("ok", false):
        return
    if stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _present_result(result)

func _swing() -> void:
    var progress: float = float(stadium.get_pitch_progress()) if session.is_live_pitch() else 0.0
    var result: Dictionary = session.swing(progress)
    if not result.get("ok", false):
        if str(result.get("toast", "")) != "":
            _show_toast(str(result["toast"]))
        return
    if result.get("play_hit", false) and result.has("outcome") and stadium.has_method("swing_to"):
        var outcome: Dictionary = result["outcome"]
        stadium.swing_to(Vector2(float(outcome["flight_x"]), float(outcome["flight_y"])))
    elif result.get("cancel_pitch", false) and stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _present_result(result)

func _present_result(result: Dictionary) -> void:
    cpu_swing_token += 1
    auto_pitch_token += 1
    var burst := str(result.get("burst", ""))
    if burst != "":
        _show_burst(burst, str(result.get("burst_kind", "")))
    _update_ui()
    var followup := str(result.get("followup", "none"))
    if followup == "prepare":
        _finish_resolution(Callable(self, "_prepare_next_pitch").bind(str(result.get("prepare_message", ""))), float(result.get("delay", 0.9)))
    elif followup == "switch_half" or followup == "advance_inning":
        _finish_resolution(Callable(self, "_switch_half"), float(result.get("delay", 1.1)))

func _switch_half() -> void:
    var current_token := resolution_token
    var result: Dictionary = session.switch_half()
    _update_ui()
    _sync_half_controls()
    if result.get("game_over", false):
        _set_controls_disabled(true)
        pitch_button.disabled = false
        pitch_button.text = "↻  再來一場\nPLAY AGAIN"
        var won := bool(result.get("won", false))
        var player_name := str(session.player_team()["name"])
        var rival_name := str(session.rival_team()["name"])
        _set_message(
            "FINAL · WIN" if won else "FINAL · NEXT TIME",
            ("%s %d : %d %s" if won else "%s %d : %d %s") % ([player_name, session.player_score, session.rival_score, rival_name] if won else [rival_name, session.rival_score, session.player_score, player_name]),
            "按「再來一場」重新選擇角色與球隊"
        )
        _show_burst("比賽勝利！" if won else "比賽結束", "perfect" if won else "")
        _show_toast((player_name + "拿下勝利 🏆") if won else "下一場再來。")
        return
    _set_message(str(result["message_kicker"]), str(result["message_title"]), str(result["message_sub"]))
    await get_tree().create_timer(float(result.get("delay", 0.9))).timeout
    if is_inside_tree() and not session.game_over and current_token == resolution_token:
        _prepare_next_pitch(str(result.get("prepare_message", "")))

func _prepare_next_pitch(message: String = "") -> void:
    session.prepare_next_pitch()
    if stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _set_controls_disabled(false)
    _update_ui()
    if session.game_over or not session.match_ready:
        return
    _begin_half(message)

func _finish_resolution(callback: Callable, delay: float) -> void:
    resolution_token += 1
    var current_token := resolution_token
    session.resolving = true
    _set_controls_disabled(true)
    await get_tree().create_timer(delay).timeout
    if is_inside_tree() and current_token == resolution_token:
        callback.call()

func _set_controls_disabled(disabled: bool) -> void:
    if not session.match_ready:
        disabled = true
    for button in pitch_buttons.values():
        button.disabled = disabled
    for button in aim_buttons:
        button.disabled = disabled
    if pitch_button:
        pitch_button.disabled = disabled or (session.is_player_offense() and not session.game_over)
    if swing_button:
        swing_button.disabled = disabled or not session.is_live_pitch() or session.is_fielding()
    if session.game_over and pitch_button:
        pitch_button.disabled = false

func _update_ui() -> void:
    if not is_instance_valid(away_score_label):
        return
    var top := session.half == "top"
    inning_label.text = "第 " + str(session.inning) + " 局 · " + ("客隊進攻" if top else "主隊進攻")
    if half_badge_label:
        half_badge_label.text = ("▲  " if top else "▼  ") + session.half_label()
        half_badge_label.add_theme_stylebox_override("normal", _panel_style(Color("ef7e32") if top else Color("1e64c8"), Color(0, 0, 0, 0), 9))
    away_score_label.text = str(session.away_score())
    home_score_label.text = str(session.home_score())
    hero_combo_label.text = str(session.combo)
    ball_count_label.text = "B  " + _lights(session.balls, 4)
    strike_count_label.text = str("S  ") + _lights(session.strikes, 3)
    out_count_label.text = "O  " + _lights(session.outs, 3)
    var batting: Dictionary = session.batting_team()
    var role_verb := "打擊" if session.is_player_offense() else "守備"
    at_bat_label.text = "比賽結束" if session.game_over else session.half_label() + " · " + str(batting["name"]) + "進攻 · " + str(session.outs) + " OUT · " + role_verb
    mission_perfect_label.text = str(mini(session.perfects, 1)) + "/1"
    mission_hits_label.text = str(mini(session.hits, 3)) + "/3"
    mission_runs_label.text = str(mini(session.total_runs, 2)) + "/2"
    batter_state_label.text = "FINAL" if session.game_over else "COMBO ×" + str(session.combo) if session.combo > 0 else "ON DECK"
    batter_state_label.add_theme_color_override("font_color", GOLD if session.combo > 0 else Color("7192b5"))
    if stadium.has_method("set_bases"):
        stadium.set_bases(session.bases)
    _render_innings()
    _refresh_button_styles()

func _render_innings() -> void:
    _paint_inning_line(away_inning_cells, session.away_inning_runs, session.half == "top")
    _paint_inning_line(home_inning_cells, session.home_inning_runs, session.half == "bottom")

func _paint_inning_line(cells: Array[Label], runs: Array, batting: bool) -> void:
    for index in range(cells.size()):
        var value = runs[index] if index < runs.size() else null
        cells[index].text = "—" if value == null else str(value)
        var current := batting and index == session.inning - 1 and not session.game_over
        cells[index].add_theme_color_override("font_color", Color("ffffff") if current else (TEXT if value != null else Color("8ba9c8")))
        cells[index].add_theme_stylebox_override("normal", _panel_style(
            Color(0.12, 0.38, 0.72, 0.88) if current else Color("edf5ff"),
            Color(0.45, 0.72, 1.0, 0.55) if current else Color(0.15, 0.39, 0.70, 0.18),
            5
        ))

func _lights(value: int, maximum: int) -> String:
    var result := ""
    for index in range(maximum):
        result += "●" if index < value else "○"
    return result

func _set_message(kicker: String, title: String, sub: String) -> void:
    if status_kicker:
        status_kicker.text = kicker
        status_title.text = title
        status_sub.text = sub
        status_title.modulate.a = 1.0
        status_sub.modulate.a = 1.0

func _show_burst(text: String, kind: String) -> void:
    burst_label.text = text
    burst_label.add_theme_color_override("font_color", GOLD if kind == "perfect" else RED if kind == "strike" else TEXT)
    burst_label.modulate.a = 0.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(burst_label, "modulate:a", 1.0, 0.12)
    tween.tween_property(burst_label, "position:y", -116.0, 0.15)
    tween.chain().tween_property(burst_label, "modulate:a", 0.0, 0.72)
    tween.chain().tween_property(burst_label, "position:y", -142.0, 0.72)

func _show_toast(text: String) -> void:
    toast_token += 1
    var token := toast_token
    toast_label.text = text
    toast_label.visible = true
    toast_label.modulate.a = 1.0
    if toast_tween:
        toast_tween.kill()
    toast_tween = create_tween()
    toast_tween.tween_interval(1.9)
    toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)
    toast_tween.tween_callback(func():
        if token == toast_token:
            toast_label.visible = false
    )

func _next_coach_note() -> void:
    if coach_note_label == null:
        return
    coach_index = (coach_index + 1) % GameRules.COACH_NOTES.size()
    coach_note_label.text = GameRules.COACH_NOTES[coach_index]

func _toggle_sound() -> void:
    sound_on = not sound_on
    sound_button.text = "🔊" if sound_on else "🔇"
    _show_toast("音效已" + ("開啟" if sound_on else "靜音"))

func _open_tutorial() -> void:
    if tutorial:
        tutorial.popup_centered()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if tutorial and tutorial.visible:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if setup_overlay and setup_overlay.visible:
        if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
            _start_match()
            get_viewport().set_input_as_handled()
        return
    match key_event.keycode:
        KEY_ENTER, KEY_KP_ENTER, KEY_T:
            if session.game_over:
                _reset_game()
            elif session.is_fielding():
                _start_pitch()
            get_viewport().set_input_as_handled()
        KEY_SPACE:
            if session.is_player_offense():
                _swing()
            get_viewport().set_input_as_handled()
        KEY_R:
            _reset_game()
            get_viewport().set_input_as_handled()
        KEY_1:
            if session.can_choose():
                _select_pitch("fastball")
                get_viewport().set_input_as_handled()
        KEY_2:
            if session.can_choose():
                _select_pitch("curveball")
                get_viewport().set_input_as_handled()
        KEY_3:
            if session.can_choose():
                _select_pitch("slider")
                get_viewport().set_input_as_handled()
        KEY_4:
            if session.can_choose():
                _select_pitch("changeup")
                get_viewport().set_input_as_handled()
        KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
            if session.can_choose():
                session.move_aim(key_event.keycode)
                _select_aim(session.aim_zone)
                get_viewport().set_input_as_handled()

func _reset_game() -> void:
    _cancel_pending_actions()
    session.reset()
    set_process(false)
    pitch_button.text = "↗  投球\nTHROW PITCH"
    _select_pitch(session.selected_pitch)
    _select_aim(session.aim_zone)
    _set_controls_disabled(true)
    if stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _update_ui()
    _set_message("LINEUP", "先選角色與球隊", "選好後再開始比賽")
    _show_setup()
    _show_toast("回到選角，準備下一場。")

func _cancel_pending_actions() -> void:
    resolution_token += 1
    auto_pitch_token += 1
    cpu_swing_token += 1

func _show_setup() -> void:
    if setup_overlay:
        setup_overlay.visible = true
    _refresh_setup_styles()

func _on_setup_character_pressed(character_id: String) -> void:
    pending_character = character_id
    _refresh_setup_styles()

func _on_setup_team_pressed(team_id: String) -> void:
    pending_team = team_id
    _refresh_setup_styles()

func _refresh_setup_styles() -> void:
    for character_id in setup_character_buttons:
        var card: PanelContainer = setup_character_buttons[character_id]
        var selected := str(character_id) == pending_character
        card.add_theme_stylebox_override("panel", _button_style(Color("d7ecff") if selected else Color("f4f8fd"), Color("2f76cf") if selected else Color(0.14, 0.38, 0.70, 0.20), 14))
    for team_id in setup_team_buttons:
        var card: PanelContainer = setup_team_buttons[team_id]
        var selected := str(team_id) == pending_team
        card.add_theme_stylebox_override("panel", _button_style(Color("d7ecff") if selected else Color("f4f8fd"), Color("2f76cf") if selected else Color(0.14, 0.38, 0.70, 0.20), 14))
    var ready := pending_character != "" and pending_team != ""
    if setup_start_button:
        setup_start_button.disabled = not ready
        setup_start_button.add_theme_color_override("font_color", Color("ffffff"))
        setup_start_button.add_theme_stylebox_override("normal", _button_style(Color("2b70c9"), Color("74bbff"), 12))
        setup_start_button.add_theme_stylebox_override("hover", _button_style(Color("3e86df"), Color("b5e1ff"), 12))
        setup_start_button.add_theme_stylebox_override("disabled", _button_style(Color("87a8cc"), Color(0.20, 0.35, 0.55, 0.2), 12))
    if setup_summary:
        if ready:
            var character: Dictionary = GameRules.CHARACTERS[pending_character]
            var team: Dictionary = GameRules.TEAMS[pending_team]
            setup_summary.text = "以" + str(character["name"]) + "（" + str(character["role_label"]) + "）為" + str(team["name"]) + "出賽"
        else:
            setup_summary.text = "請先點選角色與球隊。"

func _start_match() -> void:
    if pending_character == "" or pending_team == "":
        return
    if not session.configure(pending_character, pending_team):
        return
    if setup_overlay:
        setup_overlay.visible = false
    _apply_match_identity()
    _begin_match()

func _apply_match_identity() -> void:
    var away_team: Dictionary = GameRules.TEAMS["away"]
    var home_team: Dictionary = GameRules.TEAMS["home"]
    var player_team: Dictionary = session.player_team()
    var character: Dictionary = session.player_character()
    if away_team_name_label:
        away_team_name_label.text = str(away_team["name"])
        away_team_sub_label.text = str(away_team["short"])
        home_team_name_label.text = str(home_team["name"])
        home_team_sub_label.text = str(home_team["short"])
    if away_crest:
        away_crest.texture = load(GameRules.art_path(str(away_team["art"]))) as Texture2D
    if home_crest:
        home_crest.texture = load(GameRules.art_path(str(home_team["art"]))) as Texture2D
    if away_tag_label:
        away_tag_label.text = "客" if session.team_id != "away" else "我"
        home_tag_label.text = "主" if session.team_id != "home" else "我"
    _sync_half_controls()
    if tutorial:
        tutorial.dialog_text = "1. 客隊先攻（上半局），主隊後攻（下半局）。三出局後攻守轉換。\n2. 打擊時：投手會在 3–15 秒內自動投球，靠近本壘再揮棒。\n3. 守備時：自己選球路投球，對手會自動揮棒。\n\n三個好球出局，四個壞球保送。"
    _update_ui()
    _show_toast(str(character["name"]) + "加入" + str(player_team["name"]) + " · 客隊上半先攻")

func _begin_match() -> void:
    _select_pitch(session.selected_pitch)
    _select_aim(session.aim_zone)
    _sync_half_controls()
    _set_controls_disabled(false)
    _begin_half("第 1 局上半開始")

func _begin_half(message: String = "") -> void:
    _sync_half_controls()
    _set_controls_disabled(false)
    if session.is_player_offense():
        _set_message(session.half_label(), message if message != "" else "輪到我們打擊", "客隊上半、主隊下半。投手 3–15 秒內投出")
        _schedule_auto_pitch()
    else:
        _set_message(session.half_label(), message if message != "" else "輪到我們守備", "選球路後按投球，對手會自動揮棒")

func _sync_half_controls() -> void:
    if not session.match_ready or session.game_over:
        return
    if controls_label:
        controls_label.text = "預判球路" if session.is_player_offense() else "選擇球路"
    if controls_hint_label:
        controls_hint_label.text = "SPACE 揮棒  ·  投手 3–15 秒自動投球" if session.is_player_offense() else "ENTER / T 投球  ·  對手自動打擊"
    if pitch_button:
        pitch_button.text = "等待投球\nCPU PITCH" if session.is_player_offense() else "↗  投球\nTHROW PITCH"

func _schedule_auto_pitch() -> void:
    if not session.is_player_offense() or session.game_over or not session.can_choose():
        return
    auto_pitch_token += 1
    var token := auto_pitch_token
    var delay := session.auto_pitch_delay()
    pitch_speed_label.text = "投手準備中 · " + str(snapped(delay, 0.1)) + " 秒內出手"
    await get_tree().create_timer(delay).timeout
    if not is_inside_tree() or token != auto_pitch_token or not session.can_choose() or session.game_over:
        return
    session.choose_cpu_pitch()
    _select_pitch(session.selected_pitch)
    _start_pitch()

func _schedule_cpu_batter() -> void:
    if not session.is_fielding() or not session.is_live_pitch():
        return
    var plan: Dictionary = session.cpu_batter_plan()
    if str(plan.get("action", "take")) != "swing":
        return
    cpu_swing_token += 1
    var token := cpu_swing_token
    var wait := float(session.active_pitch.get("duration", 1.0)) * float(plan.get("progress", 0.86))
    await get_tree().create_timer(wait).timeout
    if not is_inside_tree() or token != cpu_swing_token or not session.is_live_pitch():
        return
    var cpu_aim := GameRules.cpu_swing_aim(int(session.active_pitch.get("zone", 4)), session.rng)
    var progress: float = float(stadium.get_pitch_progress()) if session.is_live_pitch() else 0.0
    var result: Dictionary = session.swing(progress, cpu_aim)
    if not result.get("ok", false):
        return
    if result.get("play_hit", false) and result.has("outcome") and stadium.has_method("swing_to"):
        var outcome: Dictionary = result["outcome"]
        stadium.swing_to(Vector2(float(outcome["flight_x"]), float(outcome["flight_y"])))
    elif result.get("cancel_pitch", false) and stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _present_result(result)
