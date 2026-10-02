class_name ScanScreen
extends MarginContainer
## Tarama sekmesi: canlı kamera, galeri, sürekli tarama ve son taramalar.

var app: Control
var _recent_box: VBoxContainer
var _cont_switch: CheckButton
var _plugin_info: Control


func _init(app_ref: Control) -> void:
	app = app_ref
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()


func _build() -> void:
	var body := W.vbox([], 14)

	# Başlık
	var head := W.vbox([], 2)
	head.add_child(W.label("Kodu Tara", "H1Label", 30, true))
	head.add_child(W.wrap("QR ve barkodları kameradan hızlıca okuyun.", "MutedLabel", 15))
	body.add_child(head)

	# Hero kart — animasyonlu nişangah
	var hero_inner := W.vbox([], 14)
	hero_inner.add_child(Reticle.new())
	hero_inner.add_child(W.primary("Canlı Taramayı Başlat", func() -> void:
			app.start_scan(false)))
	hero_inner.add_child(W.secondary("Galeriden Kod Seç", func() -> void:
			app.start_scan(true)))
	body.add_child(W.card([hero_inner], 14))

	# Sürekli tarama
	_cont_switch = CheckButton.new()
	_cont_switch.button_pressed = bool(Store.getv("continuous"))
	_cont_switch.toggled.connect(func(v: bool) -> void:
			Store.setv("continuous", v))
	var cont_row := W.hbox([
		_wrap_pair("Sürekli tarama", "Ardışık kodları duraklatmadan okur (toplu tarama)."),
		_cont_switch,
	], 12)
	_cont_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(W.card([cont_row], 10))

	# Güvenlik kartı
	var sec := W.vbox([], 4)
	sec.add_child(W.label("GÜVENLİK", "SectionLabel", 11, true))
	sec.add_child(W.wrap("Bağlantılar açılmadan önce hedef adres önizlenir. Ayarlar’dan değiştirebilirsiniz.", "MutedLabel", 13))
	body.add_child(W.card([sec], 6))

	# Eklenti durumu
	_plugin_info = W.card([
		W.wrap("Kamera taraması Android (.apk) derlemesinde çalışır. Masaüstünde üretme, geçmiş ve ayarlar kullanılabilir.", "MutedLabel", 13),
	], 6)
	body.add_child(_plugin_info)

	# Son taramalar
	body.add_child(W.section("Son taramalar"))
	_recent_box = W.vbox([], 8)
	body.add_child(_recent_box)
	body.add_child(W.gap(8))

	add_child(W.scroll(body))


func _wrap_pair(title: String, desc: String) -> Control:
	var v := W.vbox([], 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(W.label(title, "", 16, true))
	v.add_child(W.wrap(desc, "MutedLabel", 13))
	return v


func refresh() -> void:
	if _cont_switch:
		_cont_switch.set_pressed_no_signal(bool(Store.getv("continuous")))
	if _plugin_info:
		_plugin_info.visible = not Native.available()
	if _recent_box == null:
		return
	for ch in _recent_box.get_children():
		ch.queue_free()
	var items: Array = []
	for e in Store.query("", "scan"):
		items.append(e)
		if items.size() >= 3:
			break
	if items.is_empty():
		_recent_box.add_child(W.wrap("Henüz tarama yok. İlk kodunuzu tarayın.", "MutedLabel", 14))
		return
	for e in items:
		_recent_box.add_child(_row(e))
	var all := W.ghost("Tüm geçmişi gör", func() -> void:
			app._select_tab(2))
	_recent_box.add_child(all)


func _row(e: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "SecondaryButton"
	b.custom_minimum_size = Vector2(0, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_contents = true
	b.text = "%s · %s\n%s" % [
		Payload.type_label(str(e.get("type", "text"))),
		str(e.get("title", "")),
		str(e.get("content", "")),
	]
	b.pressed.connect(func() -> void:
			app.show_result(e))
	return b


func on_retheme() -> void:
	refresh()


## --- Nişangah -------------------------------------------------------------

class Reticle:
	extends Control

	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 210)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var dark := Store.is_dark()
		var pal := AppTheme.palette(dark)
		var accent := AppTheme.ACCENT
		var inset := 14.0
		var arm := 30.0
		var thick := 4.0
		var area := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))

		# Zemin
		draw_rect(area, pal.surface2, true)

		# Köşe ayraçları
		var p := area.position
		var end := area.end
		# sol üst
		draw_line(p, p + Vector2(arm, 0), accent, thick)
		draw_line(p, p + Vector2(0, arm), accent, thick)
		# sağ üst
		draw_line(Vector2(end.x, p.y), Vector2(end.x - arm, p.y), accent, thick)
		draw_line(Vector2(end.x, p.y), Vector2(end.x, p.y + arm), accent, thick)
		# sol alt
		draw_line(Vector2(p.x, end.y), Vector2(p.x + arm, end.y), accent, thick)
		draw_line(Vector2(p.x, end.y), Vector2(p.x, end.y - arm), accent, thick)
		# sağ alt
		draw_line(end, end + Vector2(-arm, 0), accent, thick)
		draw_line(end, end + Vector2(0, -arm), accent, thick)

		# Hareketli tarama çizgisi
		var phase := 0.5 + 0.5 * sin(_t * 2.2)
		var ly := area.position.y + 18.0 + (area.size.y - 36.0) * phase
		var grad := Color(accent.r, accent.g, accent.b, 0.35 + 0.35 * sin(_t * 2.2))
		draw_line(Vector2(area.position.x + 20, ly), Vector2(area.end.x - 20, ly), grad, 2.0)

		# İnce çerçeve
		draw_rect(area, Color(accent.r, accent.g, accent.b, 0.16), false, 1.0)
