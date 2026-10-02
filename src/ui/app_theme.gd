@tool
class_name AppTheme
extends RefCounted
## QR Master görsel kimliği.
## Lacivert (#0A0E1A) + teal (#4FD1C5) — Silvia Games web sitesiyle aynı palet.

const ACCENT := Color("4FD1C5")
const ACCENT_DIM := Color("2FB8AD")
const ON_ACCENT := Color("052420")
const DANGER := Color("FF6B6B")
const WARNING := Color("FFC46B")
const SUCCESS := Color("5FE3A1")

const DARK := {
	"bg": Color("0A0E1A"),
	"surface": Color("111830"),
	"surface2": Color("1A2340"),
	"border": Color("263255"),
	"text": Color("E8EEF9"),
	"text2": Color("8FA2C4"),
	"scrim": Color("000000B4"),
}

const LIGHT := {
	"bg": Color("EEF3FA"),
	"surface": Color("FFFFFF"),
	"surface2": Color("E4EBF5"),
	"border": Color("D3DCEA"),
	"text": Color("0E1729"),
	"text2": Color("5A6A88"),
	"scrim": Color("0A0E1A99"),
}

static func palette(dark: bool) -> Dictionary:
	return DARK if dark else LIGHT


static func _sb(bg: Color, border: Color, radius: int, border_w: int = 1, margin := Vector2(14, 12)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	return sb


static func _flat(bg: Color, radius: int) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	return sb


static func build(dark: bool) -> Theme:
	var c := palette(dark)
	var t := Theme.new()
	t.default_font_size = 16

	# --- Temel stiller -------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", _sb(c.surface, c.border, 18, 1, Vector2(16, 14)))
	t.set_color("font_color", "Label", c.text)

	# --- Label varyasyonları -------------------------------------------
	t.set_type_variation("H1Label", "Label")
	t.set_color("font_color", "H1Label", c.text)
	t.set_font_size("font_size", "H1Label", 30)

	t.set_type_variation("H2Label", "Label")
	t.set_color("font_color", "H2Label", c.text)
	t.set_font_size("font_size", "H2Label", 22)

	t.set_type_variation("SectionLabel", "Label")
	t.set_color("font_color", "SectionLabel", c.text2)
	t.set_font_size("font_size", "SectionLabel", 13)

	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", c.text2)
	t.set_font_size("font_size", "MutedLabel", 14)

	t.set_type_variation("AccentLabel", "Label")
	t.set_color("font_color", "AccentLabel", ACCENT)
	t.set_font_size("font_size", "AccentLabel", 15)

	t.set_type_variation("DangerLabel", "Label")
	t.set_color("font_color", "DangerLabel", DANGER)
	t.set_font_size("font_size", "DangerLabel", 15)

	t.set_type_variation("MonoLabel", "Label")
	t.set_color("font_color", "MonoLabel", c.text)
	t.set_font_size("font_size", "MonoLabel", 14)

	# --- Button varyasyonları ------------------------------------------
	# Birincil: teal zemin, koyu yazı
	var p_norm := _sb(ACCENT, ACCENT, 14, 1, Vector2(18, 13))
	var p_hover := _sb(ACCENT.lightened(0.06), ACCENT, 14, 1, Vector2(18, 13))
	var p_press := _sb(ACCENT_DIM, ACCENT_DIM, 14, 1, Vector2(18, 13))
	var p_dis := _sb(c.surface2, c.border, 14, 1, Vector2(18, 13))
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", p_norm)
	t.set_stylebox("hover", "PrimaryButton", p_hover)
	t.set_stylebox("pressed", "PrimaryButton", p_press)
	t.set_stylebox("disabled", "PrimaryButton", p_dis)
	t.set_stylebox("focus", "PrimaryButton", StyleBoxFlat.new())
	t.set_color("font_color", "PrimaryButton", ON_ACCENT)
	t.set_color("font_hover_color", "PrimaryButton", ON_ACCENT)
	t.set_color("font_pressed_color", "PrimaryButton", ON_ACCENT)
	t.set_color("font_disabled_color", "PrimaryButton", c.text2)
	t.set_font_size("font_size", "PrimaryButton", 17)

	# İkincil: yüzey zemin, ince kenarlık
	var s_norm := _sb(c.surface2, c.border, 14, 1, Vector2(18, 13))
	var s_hover := _sb(c.surface2.lightened(0.05 if dark else 0.03), c.text2, 14, 1, Vector2(18, 13))
	var s_press := _sb(c.surface, c.border, 14, 1, Vector2(18, 13))
	t.set_type_variation("SecondaryButton", "Button")
	t.set_stylebox("normal", "SecondaryButton", s_norm)
	t.set_stylebox("hover", "SecondaryButton", s_hover)
	t.set_stylebox("pressed", "SecondaryButton", s_press)
	t.set_stylebox("focus", "SecondaryButton", StyleBoxFlat.new())
	t.set_color("font_color", "SecondaryButton", c.text)
	t.set_color("font_hover_color", "SecondaryButton", c.text)
	t.set_color("font_pressed_color", "SecondaryButton", ACCENT)
	t.set_font_size("font_size", "SecondaryButton", 16)

	# Hayalet: şeffaf, teal yazı
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "GhostButton", _sb(c.surface2, c.border, 12, 1, Vector2(14, 10)))
	t.set_stylebox("pressed", "GhostButton", _sb(c.surface, c.border, 12, 1, Vector2(14, 10)))
	t.set_stylebox("focus", "GhostButton", StyleBoxFlat.new())
	t.set_color("font_color", "GhostButton", ACCENT)
	t.set_color("font_hover_color", "GhostButton", ACCENT.lightened(0.1))
	t.set_color("font_pressed_color", "GhostButton", ACCENT_DIM)
	t.set_font_size("font_size", "GhostButton", 15)

	# Tehlike
	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", _sb(c.surface, DANGER, 14, 1, Vector2(18, 13)))
	t.set_stylebox("hover", "DangerButton", _sb(DANGER.darkened(0.1), DANGER, 14, 1, Vector2(18, 13)))
	t.set_stylebox("pressed", "DangerButton", _sb(DANGER.darkened(0.25), DANGER, 14, 1, Vector2(18, 13)))
	t.set_stylebox("focus", "DangerButton", StyleBoxFlat.new())
	t.set_color("font_color", "DangerButton", DANGER)
	t.set_color("font_hover_color", "DangerButton", DANGER.lightened(0.1))
	t.set_color("font_pressed_color", "DangerButton", Color.WHITE)
	t.set_font_size("font_size", "DangerButton", 16)

	# Alt çubuk sekmesi
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "TabButton", _sb(c.surface2, c.border, 12, 1, Vector2(8, 6)))
	t.set_stylebox("pressed", "TabButton", _sb(c.surface, c.border, 12, 1, Vector2(8, 6)))
	t.set_stylebox("focus", "TabButton", StyleBoxFlat.new())
	t.set_color("font_color", "TabButton", c.text2)
	t.set_color("font_hover_color", "TabButton", c.text)
	t.set_color("font_pressed_color", "TabButton", ACCENT)
	t.set_font_size("font_size", "TabButton", 13)

	# Etiket çipi (filtre)
	t.set_type_variation("ChipButton", "Button")
	t.set_stylebox("normal", "ChipButton", _sb(c.surface2, c.border, 99, 1, Vector2(13, 7)))
	t.set_stylebox("hover", "ChipButton", _sb(c.surface2, c.text2, 99, 1, Vector2(13, 7)))
	t.set_stylebox("pressed", "ChipButton", _sb(ACCENT, ACCENT, 99, 1, Vector2(13, 7)))
	t.set_stylebox("focus", "ChipButton", StyleBoxFlat.new())
	t.set_color("font_color", "ChipButton", c.text2)
	t.set_color("font_hover_color", "ChipButton", c.text)
	t.set_color("font_pressed_color", "ChipButton", ON_ACCENT)
	t.set_font_size("font_size", "ChipButton", 14)

	# --- LineEdit --------------------------------------------------------
	var f_norm := _sb(c.surface, c.border, 12, 1, Vector2(14, 12))
	var f_hover := _sb(c.surface, c.text2, 12, 1, Vector2(14, 12))
	var f_focus := _sb(c.surface, ACCENT, 12, 2, Vector2(14, 12))
	t.set_stylebox("normal", "LineEdit", f_norm)
	t.set_stylebox("hover", "LineEdit", f_hover)
	t.set_stylebox("focus", "LineEdit", f_focus)
	t.set_stylebox("read_only", "LineEdit", _sb(c.surface2, c.border, 12, 1, Vector2(14, 12)))
	t.set_color("font_color", "LineEdit", c.text)
	t.set_color("font_placeholder_color", "LineEdit", c.text2)
	t.set_color("font_uneditable_color", "LineEdit", c.text2)
	t.set_font_size("font_size", "LineEdit", 16)

	# --- CheckButton (anahtar) ------------------------------------------
	t.set_color("font_color", "CheckButton", c.text)
	t.set_font_size("font_size", "CheckButton", 16)
	t.set_color("icon_checked_color", "CheckButton", ACCENT)
	t.set_color("icon_hover_color", "CheckButton", ACCENT.lightened(0.1))

	# --- OptionButton (açılır liste) ------------------------------------
	t.set_stylebox("normal", "OptionButton", _sb(c.surface, c.border, 12, 1, Vector2(14, 11)))
	t.set_stylebox("hover", "OptionButton", _sb(c.surface2, c.text2, 12, 1, Vector2(14, 11)))
	t.set_stylebox("pressed", "OptionButton", _sb(c.surface, ACCENT, 12, 1, Vector2(14, 11)))
	t.set_stylebox("focus", "OptionButton", StyleBoxFlat.new())
	t.set_color("font_color", "OptionButton", c.text)
	t.set_color("font_hover_color", "OptionButton", c.text)
	t.set_font_size("font_size", "OptionButton", 16)

	# --- Kaydırma çubuğu --------------------------------------------------
	var grab := StyleBoxFlat.new()
	grab.bg_color = c.border
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber_normal", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	var grab_h := grab.duplicate()
	t.set_stylebox("grabber_normal", "HScrollBar", grab_h)
	t.set_stylebox("grabber_highlight", "HScrollBar", grab_h)
	t.set_stylebox("grabber_pressed", "HScrollBar", grab_h)
	t.set_stylebox("scroll", "HScrollBar", StyleBoxEmpty.new())

	# --- Popup / dialog penceresi ----------------------------------------
	t.set_stylebox("panel", "PopupPanel", _sb(c.surface, c.border, 20, 1, Vector2(4, 4)))

	return t
