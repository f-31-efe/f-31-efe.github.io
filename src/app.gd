extends Control
## QR Master — uygulama kabuğu.
## Sekmeler, tema, modal sistemi, tarama olay akışı ve reklam yerleşimi.

const TABS := ["Tara", "Oluştur", "Geçmiş", "Ayarlar"]
const APP_VERSION := "1.0.0"

var screens: Array = []
var tab := 0

var _bg: ColorRect
var _screen_host: Control
var _tab_buttons: Array = []
var _banner_holder: Control
var _modal_layer: Control
var _modal_center: CenterContainer
var _modal_panel: PanelContainer
var _toast_box: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

var _scan_pending: Array = []


func _ready() -> void:
	theme = AppTheme.build(Store.is_dark())
	_build_ui()
	_select_tab(0)

	Native.event.connect(_on_native_event)
	Store.changed.connect(_on_store_changed)

	Native.init_ads()
	Native.show_banner()
	Native.load_interstitial()
	_banner_holder.custom_minimum_size.y = Native.banner_height()


# --- İskelet -----------------------------------------------------------------

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = AppTheme.palette(Store.is_dark()).bg
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_screen_host = Control.new()
	_screen_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_screen_host)

	# Ekranları oluştur
	var defs := [
		preload("res://src/screens/scan_screen.gd"),
		preload("res://src/screens/create_screen.gd"),
		preload("res://src/screens/history_screen.gd"),
		preload("res://src/screens/settings_screen.gd"),
	]
	for i in defs.size():
		var screen: Control = defs[i].new(self)
		screen.visible = false
		_screen_host.add_child(screen)
		screens.append(screen)

	# Alt bölme + sekmeler
	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 0)
	root.add_child(bar_box)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	W.track_divider(div)
	bar_box.add_child(div)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 8)
	bar_margin.add_theme_constant_override("margin_right", 8)
	bar_margin.add_theme_constant_override("margin_top", 4)
	bar_margin.add_theme_constant_override("margin_bottom", 6)
	bar_box.add_child(bar_margin)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	bar_margin.add_child(h)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		var idx := i
		b.pressed.connect(func(): _select_tab(idx))
		h.add_child(b)
		_tab_buttons.append(b)

	# Reklam bandı için ayrılan alan (yoksa yükseklik 0)
	_banner_holder = Control.new()
	_banner_holder.custom_minimum_size = Vector2(0, 0)
	_banner_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_child(_banner_holder)

	# Modal katmanı
	_modal_layer = Control.new()
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.visible = false
	_modal_layer.z_index = 50
	add_child(_modal_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(scrim)

	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(_modal_center)

	_modal_panel = PanelContainer.new()
	_modal_panel.visible = false
	_modal_center.add_child(_modal_panel)

	# Toast
	_toast_box = PanelContainer.new()
	_toast_box.visible = false
	_toast_box.z_index = 60
	add_child(_toast_box)
	_toast_label = W.toast_label("")
	_toast_box.add_child(_toast_label)


# --- Sekmeler ----------------------------------------------------------------

func _select_tab(i: int) -> void:
	tab = i
	for s in screens.size():
		screens[s].visible = (s == i)
	for b in _tab_buttons.size():
		_tab_buttons[b].set_pressed_no_signal(b == i)
	_update_tab_colors()


func _update_tab_colors() -> void:
	var c := AppTheme.palette(Store.is_dark())
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		if i == tab:
			b.add_theme_color_override("font_color", AppTheme.ACCENT)
		else:
			b.add_theme_color_override("font_color", c.text2)


func refresh_all() -> void:
	for s in screens:
		if s.has_method("refresh"):
			s.refresh()


# --- Tema --------------------------------------------------------------------

func _on_store_changed(key: String, _value: Variant) -> void:
	if key == "theme":
		retheme()


func retheme() -> void:
	var dark := Store.is_dark()
	theme = AppTheme.build(dark)
	_bg.color = AppTheme.palette(dark).bg
	W.recolor_dividers(dark)
	_update_tab_colors()
	for s in screens:
		if s.has_method("on_retheme"):
			s.on_retheme()


# --- Toast -------------------------------------------------------------------

func toast(text: String, ms := 2200) -> void:
	_toast_label.text = text
	_toast_box.visible = true
	var w: float = maxf(size.x - 48.0, 160.0)
	_toast_box.custom_minimum_size = Vector2(w, 0)
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	_toast_box.offset_left = -w / 2.0
	_toast_box.offset_right = w / 2.0
	_toast_box.offset_bottom = -96.0
	_toast_box.offset_top = _toast_box.offset_bottom - 56.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_box.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_box, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(ms / 1000.0)
	_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func(): _toast_box.visible = false)


# --- Modal ------------------------------------------------------------------

func _present_modal(title: String, body: Control, width_ratio := 0.88) -> void:
	for ch in _modal_panel.get_children():
		_modal_panel.remove_child(ch)
		ch.queue_free()
	var w: float = maxf(size.x * width_ratio, 240.0)
	_modal_panel.custom_minimum_size = Vector2(w, 0)
	var v := W.vbox([], 14)
	if title != "":
		v.add_child(W.label(title, "H2Label", 20, true))
	v.add_child(body)
	_modal_panel.add_child(v)
	_modal_layer.visible = true
	_modal_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_modal_panel, "modulate:a", 1.0, 0.16)


func _close_modal() -> void:
	_modal_layer.visible = false
	for ch in _modal_panel.get_children():
		_modal_panel.remove_child(ch)
		ch.queue_free()


func _modal_open() -> bool:
	return _modal_layer.visible


# Onay diyaloğu geri çağrısı
var _confirm_cb: Callable = Callable()

func confirm(title: String, message: String, cb: Callable) -> void:
	_confirm_cb = cb
	var body := W.vbox([], 8)
	body.add_child(W.wrap(message, "MutedLabel", 15))
	body.add_child(W.gap(4))
	var row := W.hbox([W.ghost("Vazgeç", _close_modal), W.danger("Onayla", _confirm_accept)], 10)
	row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	_present_modal(title, body, 0.82)


func _confirm_accept() -> void:
	_close_modal()
	if _confirm_cb.is_valid():
		_confirm_cb.call()
	_confirm_cb = Callable()


# --- Sonuç modalı ------------------------------------------------------------

func show_result(entry: Dictionary) -> void:
	var text := str(entry.get("content", ""))
	if text == "":
		return
	var meta := Payload.classify(text)
	var mtype := str(entry.get("type", meta.type))
	var body := W.vbox([], 12)

	# Başlık satırı: tür rozeti + zaman
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := int(entry.get("ts", Time.get_unix_time_from_system()))
	var when := "%s %s" % [Time.get_date_string_from_unix_time(ts), Time.get_time_string_from_unix_time(ts)]
	body.add_child(W.hbox([
		W.label(Payload.type_label(mtype), "SectionLabel", 12, true),
		spacer,
		W.label(when, "MutedLabel", 12),
	], 8))

	# İçerik (kopyalanabilir)
	var te := TextEdit.new()
	te.editable = false
	te.text = text
	te.custom_minimum_size = Vector2(0, 104)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(te)

	# URL güvenlik kartı
	var suspicious := false
	if mtype == "url":
		suspicious = Payload.is_suspicious_url(text)
		var scheme := text.get_slice(":", 0).to_lower()
		var info := W.vbox([], 4)
		info.add_child(W.label("HEDEF ADRES", "SectionLabel", 11, true))
		info.add_child(W.wrap(Payload.host_of(text), "MonoLabel", 15))
		if suspicious:
			info.add_child(W.wrap("Dikkat: bu bağlantı riskli görünüyor. Açmadan önce adresi dikkatlice kontrol edin.", "DangerLabel", 13))
		elif scheme == "http":
			info.add_child(W.wrap("Güvenli olmayan bağlantı (http). Şifre veya kişisel bilgi girmeyin.", "DangerLabel", 13))
		else:
			info.add_child(W.wrap("Bağlantı güvenli (https).", "AccentLabel", 13))
		body.add_child(W.card([info]))

	# Eylemler
	var actions := W.vbox([], 8)
	var can_open := Payload.can_open(text)

	var row1 := W.hbox([], 8)
	if can_open:
		var open_btn: Button
		if suspicious:
			open_btn = W.danger("Yine de Aç", func() -> void:
				_confirm_open(text))
		else:
			open_btn = W.primary(_open_label(mtype), func() -> void:
				_open_entry(text))
		open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(open_btn)
	var copy_btn := W.secondary("Kopyala", func() -> void:
		DisplayServer.clipboard_set(text)
		toast("Panoya kopyalandı"))
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(copy_btn)
	actions.add_child(row1)

	var row2 := W.hbox([], 8)
	var share_btn := W.secondary("Paylaş", func() -> void:
		Native.share_text(text))
	share_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(share_btn)
	if mtype == "text" or mtype == "url":
		var search_btn := W.secondary("Web’de Ara", func() -> void:
			_search_web(text))
		search_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(search_btn)
	actions.add_child(row2)

	var row3 := W.hbox([], 8)
	var eid := str(entry.get("id", ""))
	if eid != "":
		var fav_btn := W.ghost(
			"Favoriden Çıkar" if bool(entry.get("fav", false)) else "Favorilere Ekle",
			func() -> void:
					Store.toggle_fav(eid)
					toast("Favoriler güncellendi")
					show_result(Store.find_entry(eid)))
		fav_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row3.add_child(fav_btn)
	var close_btn := W.ghost("Kapat", _close_modal)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(close_btn)
	actions.add_child(row3)

	body.add_child(actions)
	_present_modal("", body, 0.9)


func _open_label(mtype: String) -> String:
	match mtype:
		"phone":
			return "Ara"
		"sms":
			return "Mesaj Yaz"
		"email":
			return "E‑posta Yaz"
		"location":
			return "Haritada Aç"
		"app":
			return "Mağazada Aç"
	return "Aç"


func _open_entry(text: String) -> void:
	_close_modal()
	if not Native.open_uri(text):
		toast("Bu içerik bu cihazda açılamıyor")


func _confirm_open(text: String) -> void:
	confirm("Riskli bağlantı", "Bu bağlantı güvenli görünmüyor:\n%s\n\nYine de açmak istiyor musunuz?" % Payload.host_of(text), func() -> void:
		Native.open_uri(text))


func _search_web(text: String) -> void:
	var q := text
	if text.to_lower().begins_with("http"):
		q = Payload.host_of(text)
	_close_modal()
	Native.open_uri("https://www.google.com/search?q=" + q.uri_encode())


# --- Tarama akışı ------------------------------------------------------------

func start_scan(auto_gallery := false) -> void:
	if not Native.available():
		toast("Kamera taraması Android (.apk) derlemesinde çalışır")
		return
	_scan_pending.clear()
	Native.start_scan({
		"continuous": bool(Store.getv("continuous")),
		"auto_gallery": auto_gallery,
		"gallery_button": true,
	})


func _on_native_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"scan_result":
			var text := str(e.get("text", ""))
			if text != "":
				_scan_pending.append(text)
				if bool(Store.getv("auto_copy")):
					DisplayServer.clipboard_set(text)
				if bool(Store.getv("sound")):
					Native.beep()
				Native.vibrate(35)
				if not bool(Store.getv("continuous")):
					Native.stop_scan()
		"scan_closed":
			_drain_scan_results()
		"scan_error":
			toast(str(e.get("message", "Tarama başlatılamadı")))
		"image_saved":
			if bool(e.get("ok", false)):
				toast("Galeriye kaydedildi")
			else:
				toast(str(e.get("message", "Kaydedilemedi")))


func _drain_scan_results() -> void:
	var pending := _scan_pending.duplicate()
	_scan_pending.clear()
	if pending.is_empty():
		return
	if pending.size() > 1:
		for i in range(pending.size() - 1):
			_record_scan(pending[i])
		toast("%d kod tarandı" % pending.size())
	_present_scan_result(pending[pending.size() - 1])
	_count_scan_session()


func _record_scan(text: String) -> Dictionary:
	var meta := Payload.classify(text)
	var entry := Store.add_entry("scan", meta.type, text, meta.title)
	if entry.is_empty():
		entry = {
			"id": "", "kind": "scan", "type": meta.type, "content": text,
			"title": meta.title, "ts": int(Time.get_unix_time_from_system()),
			"fav": false, "extra": {},
		}
	return entry


func _present_scan_result(text: String) -> void:
	var entry := _record_scan(text)
	var meta := Payload.classify(text)
	if meta.type == "url" and bool(Store.getv("auto_open")) \
			and not bool(Store.getv("url_preview")) and not Payload.is_suspicious_url(text):
		Native.open_uri(text)
		toast("Bağlantı açıldı: " + str(meta.title))
	else:
		show_result(entry)
	refresh_all()


func _count_scan_session() -> void:
	var n := int(Store.getv("scan_sessions")) + 1
	Store.setv("scan_sessions", n)
	var every := int(Store.getv("interstitial_every"))
	if every > 0 and n % every == 0:
		if Native.show_interstitial():
			Native.load_interstitial()


# --- Dışa aktarma ------------------------------------------------------------

func export_csv() -> void:
	if Store.history().is_empty():
		toast("Dışa aktarılacak kayıt yok")
		return
	var csv := Store.export_csv()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
	var path := "user://exports/qr_master_gecmis_%s.csv" % Time.get_date_string_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast("Dosya yazılamadı")
		return
	f.store_string(csv)
	f.close()
	if Native.available():
		Native.share_file(ProjectSettings.globalize_path(path), "text/csv")
		toast("Paylaşım menüsü açıldı")
	else:
		toast("CSV kaydedildi")


## KOD SONU
# >>> APP_END <<<
