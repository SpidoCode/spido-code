extends Button
## Shared primary palette, with each Original button retaining its own geometry.

const TEXT_COLORS := [&"font_color", &"font_hover_color", &"font_pressed_color",
	&"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]


func _ready() -> void:
	apply(self)


static func apply(button: Button) -> void:
	var base := button.get_theme_stylebox(&"normal") as StyleBoxFlat
	if base == null:
		return

	var normal := _recolor(base, Color("#80BC87"), Color("#609769"))
	var hover := _recolor(base, Color("#67A975"), Color("#B6DEC0"))
	var pressed := _recolor(base, Color("#70A978"), Color("#507D58"))
	var sink := minf(3.0, base.get_margin(SIDE_BOTTOM))
	pressed.content_margin_top = base.get_margin(SIDE_TOP) + sink
	pressed.content_margin_bottom = base.get_margin(SIDE_BOTTOM) - sink
	pressed.set_border_width(SIDE_TOP, base.get_border_width(SIDE_TOP) + int(sink))
	pressed.set_border_width(SIDE_BOTTOM, maxi(0, base.get_border_width(SIDE_BOTTOM) - int(sink)))
	pressed.shadow_offset = base.shadow_offset - Vector2(0, sink)

	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.shadow_size = 0
	focus.set_border_width_all(2)
	focus.border_color = Color("#304E39")

	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"focus", focus)
	if button.toggle_mode:
		# A latched button retains its selected color at full height.
		var selected := _recolor(base, pressed.bg_color, pressed.border_color)
		_set_pressed_style(button, selected)
		button.button_down.connect(_set_pressed_style.bind(button, pressed))
		button.button_up.connect(_set_pressed_style.bind(button, selected))
	else:
		_set_pressed_style(button, pressed)

	var disabled_color := button.get_theme_color(&"font_disabled_color")
	_update_cursor(button)
	button.draw.connect(_update_cursor.bind(button))
	# Leave native layout and rendering in charge of icons and nonstandard text.
	var native_text := button.icon != null or button.has_theme_icon(&"icon") or (
		button.autowrap_mode != TextServer.AUTOWRAP_OFF or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	)
	for item in TEXT_COLORS:
		if item != &"font_disabled_color" or not native_text:
			button.add_theme_color_override(item, Color.WHITE if native_text else Color.TRANSPARENT)
	if not native_text:
		button.add_theme_constant_override(&"outline_size", 0)
		button.draw.connect(_draw_text.bind(button, disabled_color))


static func _recolor(base: StyleBoxFlat, fill: Color, border: Color) -> StyleBoxFlat:
	var box := base.duplicate() as StyleBoxFlat
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, base.get_margin(side))
	box.bg_color = fill
	box.border_color = border
	return box


static func _set_pressed_style(button: Button, box: StyleBoxFlat) -> void:
	button.add_theme_stylebox_override(&"pressed", box)
	button.add_theme_stylebox_override(&"hover_pressed", box)


static func _update_cursor(button: Button) -> void:
	var cursor := Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	if button.mouse_default_cursor_shape != cursor:
		button.mouse_default_cursor_shape = cursor


static func _draw_text(button: Button, disabled_color: Color) -> void:
	var state: StringName = &"normal"
	match button.get_draw_mode():
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
			state = &"pressed"
		BaseButton.DRAW_HOVER:
			state = &"hover"
		BaseButton.DRAW_DISABLED:
			state = &"disabled"

	var box := button.get_theme_stylebox(state)
	var line := TextLine.new()
	line.add_string(button.tr(button.text), button.get_theme_font(&"font"), button.get_theme_font_size(&"font_size"))
	var available := button.size - box.get_minimum_size() - line.get_size()
	var origin := box.get_offset() + Vector2(0, available.y * 0.5)
	match button.alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			origin.x += available.x * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			origin.x += available.x

	if not button.disabled:
		line.draw(button.get_canvas_item(), origin + Vector2(0, 2), Color("#304E39"))
	line.draw(button.get_canvas_item(), origin, disabled_color if button.disabled else Color.WHITE)
