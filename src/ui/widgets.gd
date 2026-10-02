@tool
class_name W
extends RefCounted
## Arayüz kurma yardımcıları — tekrar eden kontrol şablonlarını sadeleştirir.

static var _semi_cache: FontVariation
static var _dividers: Array = []

## Tema değişiminde çizgi renklerini tazelemek için uygulama tarafından çağrılır.
static func recolor_dividers(dark: bool) -> void:
	var border: Color = AppTheme.palette(dark).border
	for d in _dividers:
		if is_instance_valid(d):
			d.color = border

static func track_divider(node: ColorRect) -> void:
	_dividers.append(node)


static func _semi() -> FontVariation:
	if _semi_cache == null:
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.35
		_semi_cache = fv
	return _semi_cache


static func semi_bold(c: Control) -> void:
	c.add_theme_font_override("font", _semi())


# --- Metin -------------------------------------------------------------

static func label(text: String, variation := "", size := 0, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if bold:
		semi_bold(l)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(text: String, variation := "", size := 0) -> Label:
	var l := label(text, variation, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func section(text: String) -> Label:
	var l := label(text.to_upper(), "SectionLabel", 13, true)
	l.add_theme_constant_override("outline_size", 0)
	return l


# --- Düğmeler -----------------------------------------------------------

static func _btn(text: String, cb: Callable, variation: String, min_h: float) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func primary(text: String, cb := Callable()) -> Button:
	return _btn(text, cb, "PrimaryButton", 52)


static func secondary(text: String, cb := Callable()) -> Button:
	return _btn(text, cb, "SecondaryButton", 48)


static func ghost(text: String, cb := Callable()) -> Button:
	return _btn(text, cb, "GhostButton", 42)


static func danger(text: String, cb := Callable()) -> Button:
	return _btn(text, cb, "DangerButton", 48)


static func chip(text: String, cb := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "ChipButton"
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.toggle_mode = true
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


# --- Düzen ---------------------------------------------------------------

static func vbox(children: Array = [], sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for ch in children:
		if ch != null:
			v.add_child(ch)
	return v


static func hbox(children: Array = [], sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for ch in children:
		if ch != null:
			h.add_child(ch)
	return h


static func gap(h := 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func grow_gap() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func card(children: Array = [], sep := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var v := vbox(children, sep)
	p.add_child(v)
	return p


static func scroll(child: Control, h_scroll := false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if not h_scroll else ScrollContainer.SCROLL_MODE_AUTO
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func divider() -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = AppTheme.palette(Store.is_dark()).border
	track_divider(r)
	return r


# --- Alanlar ---------------------------------------------------------------

static func labeled_field(title: String, placeholder := "", value := "", multiline := false, max_len := 0) -> Control:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.max_length = max_len if max_len > 0 else 4096
	if multiline:
		var te := TextEdit.new()
		te.placeholder_text = placeholder
		te.text = value
		te.custom_minimum_size = Vector2(0, 120)
		te.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.scroll_fit_content_height = true
		return vbox([label(title, "SectionLabel", 13, true), te], 6)
	e.custom_minimum_size = Vector2(0, 48)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return vbox([label(title, "SectionLabel", 13, true), e], 6)


## labeled_field'dan LineEdit/TextEdit erişimi için yardımcı
static func field_edit(control: Control) -> LineEdit:
	return control.get_child(1) as LineEdit


static func toggle_row(title: String, desc: String, value: bool, cb: Callable) -> Control:
	var left := vbox([], 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(label(title, "", 16, true))
	if desc != "":
		left.add_child(W.wrap(desc, "MutedLabel", 13))
	var sw := CheckButton.new()
	sw.button_pressed = value
	sw.toggle_mode = true
	sw.custom_minimum_size = Vector2(0, 40)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.pressed.connect(func(): cb.call(sw.button_pressed))
	var row := hbox([left, sw], 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


## Sahne üstünde kısa bildirim (toast) için temel düğüm.
static func toast_label(text: String) -> Label:
	var l := label(text, "", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
