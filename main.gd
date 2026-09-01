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

var inning_cells: Array[Label] = []
var pitch_buttons: Dictionary = {}
var aim_buttons: Array[Button] = []

var inning_label: Label
var player_score_label: Label
var rival_score_label: Label
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
    if stadium.has_signal("pitch_arrived"):
        stadium.pitch_arrived.connect(_on_pitch_arrived)
    _select_pitch("fastball")
    _select_aim(4)
    _update_ui()
    _set_message("READY?", "選球後按「投球」", "靠近本壘時按下揮棒")
    set_process(false)

func _process(_delta: float) -> void:
    if not session.is_live_pitch():
        timing_bar.value = 0.0
        set_process(false)
        return
    var progress: float = float(stadium.get_pitch_progress())
    timing_bar.value = minf(100.0, progress * 100.0)
    pitch_speed_label.text = str(session.active_pitch.get("speed", 0)) + " km/h · 球進壘中"

func _build_interface() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color("e8f4ff")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(scroll)

    var margin := MarginContainer.new()
    margin.custom_minimum_size = Vector2(1380, 0)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 22)
    scroll.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    margin.add_child(content)

    content.add_child(_build_topbar())
    content.add_child(_build_hero())

    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 14)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(body)

    var game_column := VBoxContainer.new()
    game_column.custom_minimum_size = Vector2(930, 0)
    game_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    game_column.add_theme_constant_override("separation", 12)
    body.add_child(game_column)

    game_column.add_child(_build_scoreboard())
    game_column.add_child(_build_stadium_panel())
    game_column.add_child(_build_controls())

    var side_column := VBoxContainer.new()
    side_column.custom_minimum_size = Vector2(360, 0)
    side_column.add_theme_constant_override("separation", 12)
    body.add_child(side_column)
    side_column.add_child(_build_feature_card())
    side_column.add_child(_build_mission_card())
    side_column.add_child(_build_lineup_card())
    side_column.add_child(_build_character_gallery())
    side_column.add_child(_build_coach_card())
    side_column.add_child(_build_shortcut_card())

    content.add_child(_build_design_notes())
    content.add_child(_build_footer())

    tutorial = AcceptDialog.new()
    tutorial.title = "怎麼玩 · 喵喵棒球"
    tutorial.dialog_text = "1. 選一個預判球路。\n2. 按「投球」，盯著球進入好球帶。\n3. 在 Timing Window 的綠色區域按下揮棒。\n\nPerfect 會帶來更高的長打機率。三個好球出局，四個壞球保送。"
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
    bar.custom_minimum_size = Vector2(0, 74)
    bar.add_theme_stylebox_override("panel", _panel_style(Color(0.99, 1.0, 1.0, 0.98), Color(0.13, 0.40, 0.78, 0.34), 18))
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    row.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
    var pad := _pad(row, 13, 16, 13, 16)
    bar.add_child(pad)
    var logo_texture := load("res://assets/generated/logo-v1.png") as Texture2D
    if logo_texture:
        var logo := TextureRect.new()
        logo.texture = logo_texture
        logo.custom_minimum_size = Vector2(190, 68)
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
    var combo_panel := PanelContainer.new()
    combo_panel.custom_minimum_size = Vector2(158, 70)
    combo_panel.add_theme_stylebox_override("panel", _panel_style(Color("fff6dd"), Color(0.95, 0.58, 0.10, 0.48), 16))
    var combo_row := HBoxContainer.new()
    combo_row.add_theme_constant_override("separation", 9)
    combo_panel.add_child(_pad(combo_row, 10, 15, 10, 15))
    var combo_texture := load("res://assets/generated/combo-badge-v1.png") as Texture2D
    if combo_texture:
        var combo_icon := TextureRect.new()
        combo_icon.custom_minimum_size = Vector2(43, 43)
        combo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        combo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        combo_icon.texture = combo_texture
        combo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        combo_row.add_child(combo_icon)
    else:
        combo_row.add_child(_label("🔥", 24, GOLD))
    var combo_text := VBoxContainer.new()
    hero_combo_label = _label("0", 24, GOLD)
    var combo_caption := _label("連續安打  COMBO", 9, Color("bd7a20"))
    combo_text.add_child(hero_combo_label)
    combo_text.add_child(combo_caption)
    combo_row.add_child(combo_text)
    hero.add_child(combo_panel)
    return hero

func _build_scoreboard() -> Control:
    var panel := _make_panel(Vector2(0, 108))
    var v := _card_content(panel, 12)
    var heading := HBoxContainer.new()
    var live := _label("●  LIVE", 9, GREEN)
    heading.add_child(live)
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(fill)
    inning_label = _label("第 1 局 · 友誼賽", 10, Color("6583a5"))
    heading.add_child(inning_label)
    v.add_child(heading)

    var score_row := HBoxContainer.new()
    score_row.add_theme_constant_override("separation", 10)
    var team_box := VBoxContainer.new()
    team_box.custom_minimum_size = Vector2(145, 0)
    var player_head := HBoxContainer.new()
    player_head.add_theme_constant_override("separation", 6)
    player_head.add_child(_team_icon("res://assets/generated/home-crest-v1.png"))
    player_head.add_child(_label("喵白白隊", 12, TEXT))
    var player_sub := _label("HOME CAT  ·  喵白白", 8, Color("6f8baa"))
    team_box.add_child(player_head)
    team_box.add_child(player_sub)
    score_row.add_child(team_box)
    var strip := HBoxContainer.new()
    strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    strip.add_theme_constant_override("separation", 1)
    for i in range(9):
        var cell := _label(str(i + 1) + "\n—", 9, Color("5f7ea2"))
        cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cell.custom_minimum_size = Vector2(30, 42)
        cell.add_theme_stylebox_override("normal", _panel_style(Color("edf5ff"), Color(0.15, 0.39, 0.70, 0.18), 5))
        strip.add_child(cell)
        inning_cells.append(cell)
    score_row.add_child(strip)
    player_score_label = _label("0 R", 21, BLUE)
    player_score_label.custom_minimum_size = Vector2(55, 0)
    player_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_row.add_child(player_score_label)
    v.add_child(score_row)

    var rival_row := HBoxContainer.new()
    rival_row.add_theme_constant_override("separation", 10)
    var rival_team_box := VBoxContainer.new()
    rival_team_box.custom_minimum_size = Vector2(145, 0)
    var rival_head := HBoxContainer.new()
    rival_head.add_theme_constant_override("separation", 6)
    rival_head.add_child(_team_icon("res://assets/generated/away-crest-v1.png"))
    rival_head.add_child(_label("喵布布隊", 12, TEXT))
    rival_team_box.add_child(rival_head)
    rival_team_box.add_child(_label("AWAY CAT  ·  喵布布", 8, Color("6f8baa")))
    rival_row.add_child(rival_team_box)
    var rival_spacer := Control.new()
    rival_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rival_row.add_child(rival_spacer)
    rival_score_label = _label("0 R", 21, Color("ef7e32"))
    rival_score_label.custom_minimum_size = Vector2(55, 0)
    rival_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rival_row.add_child(rival_score_label)
    v.add_child(rival_row)

    var count_row := HBoxContainer.new()
    count_row.add_theme_constant_override("separation", 14)
    count_row.add_theme_stylebox_override("panel", _panel_style(Color("eef6ff"), Color(0.12, 0.38, 0.72, 0.12), 8))
    ball_count_label = _label("B  ○○○○", 9, Color("2d9a67"))
    strike_count_label = _label("S  ○○○", 9, Color("e79a1d"))
    out_count_label = _label("O  ○○○", 9, Color("df5d63"))
    at_bat_label = _label("喵白白打擊 · 0 OUT", 9, Color("617f9f"))
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
    var holder := _make_panel(Vector2(0, 560))
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
    status_title = _label("選球後按「投球」", 18, Color("ffffff"))
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
    var panel := _make_panel(Vector2(0, 170))
    var v := _card_content(panel, 13)
    var heading := HBoxContainer.new()
    heading.add_child(_label("預判球路", 11, TEXT))
    var fill := Control.new()
    fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(fill)
    heading.add_child(_label("ENTER / T 投球  ·  SPACE 揮棒  ·  1—4 選球", 9, Color("6b88a9")))
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

func _make_panel(min_size: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = min_size
    panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 14))
    return panel

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
    var started: Dictionary = session.start_pitch()
    if started.get("restart", false):
        _reset_game()
        return
    if not started.get("ok", false):
        return
    set_process(true)
    if stadium.has_method("start_pitch"):
        stadium.start_pitch(float(started["duration"]), str(started["kind"]), int(started["zone"]))
    _set_controls_disabled(true)
    swing_button.disabled = false
    _set_message("WATCH THE BALL", "準備揮棒！", "球越靠近本壘，Timing 越漂亮")
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
    var burst := str(result.get("burst", ""))
    if burst != "":
        _show_burst(burst, str(result.get("burst_kind", "")))
    _update_ui()
    var followup := str(result.get("followup", "none"))
    if followup == "prepare":
        _finish_resolution(Callable(self, "_prepare_next_pitch").bind(str(result.get("prepare_message", ""))), float(result.get("delay", 0.9)))
    elif followup == "advance_inning":
        _finish_resolution(Callable(self, "_advance_inning"), float(result.get("delay", 1.1)))

func _advance_inning() -> void:
    var current_token := resolution_token
    var result: Dictionary = session.advance_inning()
    _update_ui()
    if result.get("game_over", false):
        _set_controls_disabled(true)
        pitch_button.disabled = false
        pitch_button.text = "↻  再來一場\nPLAY AGAIN"
        var won := bool(result.get("won", false))
        _set_message(
            "FINAL · WIN" if won else "FINAL · NEXT TIME",
            ("喵白白隊 %d : %d 喵布布隊" if won else "喵布布隊 %d : %d 喵白白隊") % ([session.player_score, session.rival_score] if won else [session.rival_score, session.player_score]),
            "按「再來一場」重新挑戰"
        )
        _show_burst("比賽勝利！" if won else "比賽結束", "perfect" if won else "")
        _show_toast("喵白白隊拿下勝利 🏆" if won else "下一場再把球打遠。")
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
    if message != "":
        _set_message("NEXT PITCH", message, "選球路後按投球")

func _finish_resolution(callback: Callable, delay: float) -> void:
    resolution_token += 1
    var current_token := resolution_token
    session.resolving = true
    _set_controls_disabled(true)
    await get_tree().create_timer(delay).timeout
    if is_inside_tree() and current_token == resolution_token:
        callback.call()

func _set_controls_disabled(disabled: bool) -> void:
    for button in pitch_buttons.values():
        button.disabled = disabled
    for button in aim_buttons:
        button.disabled = disabled
    if pitch_button:
        pitch_button.disabled = disabled
    if swing_button:
        swing_button.disabled = disabled or not session.is_live_pitch()
    if session.game_over and pitch_button:
        pitch_button.disabled = false

func _update_ui() -> void:
    if not is_instance_valid(player_score_label):
        return
    inning_label.text = "第 " + str(session.inning) + " 局 · 友誼賽"
    player_score_label.text = str(session.player_score) + " R"
    rival_score_label.text = str(session.rival_score) + " R"
    hero_combo_label.text = str(session.combo)
    ball_count_label.text = "B  " + _lights(session.balls, 4)
    strike_count_label.text = str("S  ") + _lights(session.strikes, 3)
    out_count_label.text = "O  " + _lights(session.outs, 3)
    at_bat_label.text = "喵白白打擊 · " + str(session.outs) + " OUT" if not session.game_over else "比賽結束"
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
    for index in range(inning_cells.size()):
        var run = session.inning_runs[index]
        inning_cells[index].text = str(index + 1) + "\n" + ("—" if run == null else str(run))
        inning_cells[index].add_theme_color_override("font_color", TEXT if index == session.inning - 1 and not session.game_over else Color("8ba9c8"))
        inning_cells[index].add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.30, 0.52, 0.72) if index == session.inning - 1 and not session.game_over else Color(0.02, 0.09, 0.17, 0.56), Color(0.29, 0.51, 0.70, 0.22), 3))

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
    match key_event.keycode:
        KEY_ENTER, KEY_KP_ENTER, KEY_T:
            _start_pitch()
            get_viewport().set_input_as_handled()
        KEY_SPACE:
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
    resolution_token += 1
    session.reset()
    set_process(false)
    pitch_button.text = "↗  投球\nTHROW PITCH"
    _select_pitch(session.selected_pitch)
    _select_aim(session.aim_zone)
    _set_controls_disabled(false)
    if stadium.has_method("cancel_pitch"):
        stadium.cancel_pitch()
    _update_ui()
    _set_message("READY?", "選球後按「投球」", "靠近本壘時按下揮棒")
    _show_toast("新比賽開始，準備好揮棒！")
