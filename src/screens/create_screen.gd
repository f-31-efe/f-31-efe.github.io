class_name CreateScreen
extends MarginContainer
## Oluştur sekmesi: 9 QR türü, hata düzeltme seviyesi, renk paleti, kayıt/paylaşım.

const TYPES := [
	["url", "Bağlantı"],
	["text", "Metin"],
	["wifi", "Wi‑Fi"],
	["contact", "Kişi"],
	["phone", "Telefon"],
	["sms", "SMS"],
	["email", "E‑posta"],
	["location", "Konum"],
	["event", "Etkinlik"],
]

const PALETTES := [
	["Klasik", Color(0, 0, 0)],
	["Lacivert", Color("12264C")],
	["Teal", Color("0B4F4A")],
	["Bordo", Color("59121C")],
	["Zümrüt", Color("064E3B")],
	["Grafit", Color("1F2937")],
]

const FORMS := {
	"url": [["Adres", "url", "ornek.com/yol", "line"]],
	"text": [["Metin", "text", "Kodunuzdaki yazı", "text"]],
	"wifi": [
		["Ağ adı (SSID)", "ssid", "Ev_WiFi", "line"],
		["Şifre", "wpass", "Ağ şifresi", "line"],
		["Güvenlik", "sec", "", "select", ["WPA/WPA2", "WEP", "Şifresiz"]],
		["Gizli ağ", "hidden", "", "check"],
	],
	"contact": [
		["Ad Soyad", "name", "Ayşe Yılmaz", "line"],
		["Organizasyon", "org", "Şirket (isteğe bağlı)", "line"],
		["Telefon", "tel", "+90 5xx", "line"],
		["E‑posta", "mail", "ornek@site.com", "line"],
		["Web", "web", "site.com", "line"],
		["Adres", "adr", "Adres (isteğe bağlı)", "text"],
	],
	"phone": [["Telefon numarası", "num", "+90 555 123 45 67", "line"]],
	"sms": [
		["Numara", "num", "+90 5xx", "line"],
		["Mesaj", "msg", "Mesaj metni", "text"],
	],
	"email": [
		["Kime", "to", "ornek@site.com", "line"],
		["Konu", "subject", "Konu", "line"],
		["Mesaj", "body", "E‑posta metni", "text"],
	],
	"location": [
		["Enlem", "lat", "41.0082", "line"],
		["Boylam", "lon", "28.9784", "line"],
	],
	"event": [
		["Başlık", "title", "Toplantı", "line"],
		["Yer", "loc", "Konum (isteğe bağlı)", "line"],
		["Tarih", "date", "2026-10-02", "line"],
		["Saat", "time", "14:30", "line"],
		["Bitiş tarihi", "edate", "2026-10-02", "line"],
		["Bitiş saati", "etime", "16:00", "line"],
	],
}

const ECC_INFO := {
	"L": "≈ %7 düzeltme — en büyük kapasite",
	"M": "≈ %15 düzeltme — dengeli (öneri)",
	"Q": "≈ %25 düzeltme — logolu baskılar",
	"H": "≈ %30 düzeltme — dayanıklı baskı",
}

var app: Control

var _type := "url"
var _fields: Dictionary = {}
var _type_chips: Dictionary = {}
var _ecc_chips: Dictionary = {}
var _pal_chips: Dictionary = {}
var _form_box: VBoxContainer
var _result_box: VBoxContainer
var _ecc_hint: Label
var _last_texture: ImageTexture = null
var _last_payload := ""
var _last_meta := ""


func _init(app_ref: Control) -> void:
	app = app_ref
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()


func _build() -> void:
	var body := W.vbox([], 14)

	var head := W.vbox([], 2)
	head.add_child(W.label("QR Kod Oluştur", "H1Label", 30, true))
	head.add_child(W.wrap("Bağlantı, Wi‑Fi, kişi kartı ve daha fazlası.", "MutedLabel", 15))
	body.add_child(head)

	# Tür seçimi (satır saran çipler)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for t in TYPES:
		var key: String = t[0]
		var c := W.chip(t[1])
		c.toggle_mode = true
		c.button_group = group
		c.set_pressed_no_signal(key == _type)
		var k := key
		c.pressed.connect(func() -> void:
				_set_type(k))
		flow.add_child(c)
		_type_chips[key] = c
	body.add_child(flow)

	# Form
	_form_box = W.vbox([], 12)
	body.add_child(W.card([_form_box], 14))
	_build_form()

	# Seçenekler: ECC + palet
	var opt := W.vbox([], 10)
	opt.add_child(W.label("HATA DÜZELTME", "SectionLabel", 11, true))
	var ecc_row := HFlowContainer.new()
	ecc_row.add_theme_constant_override("h_separation", 8)
	var eg := ButtonGroup.new()
	eg.allow_unpress = false
	for lvl in ["L", "M", "Q", "H"]:
		var c2 := W.chip(lvl)
		c2.toggle_mode = true
		c2.button_group = eg
		c2.set_pressed_no_signal(lvl == str(Store.getv("ecc")))
		var l2: String = lvl
		c2.pressed.connect(func() -> void:
				Store.setv("ecc", l2)
				_sync_ecc())
		ecc_row.add_child(c2)
		_ecc_chips[lvl] = c2
	opt.add_child(ecc_row)
	_ecc_hint = W.wrap(str(ECC_INFO[str(Store.getv("ecc"))]), "MutedLabel", 13)
	opt.add_child(_ecc_hint)

	opt.add_child(W.label("RENK", "SectionLabel", 11, true))
	var pal_row := HFlowContainer.new()
	pal_row.add_theme_constant_override("h_separation", 8)
	var pg := ButtonGroup.new()
	pg.allow_unpress = false
	for i in PALETTES.size():
		var c3 := W.chip(PALETTES[i][0])
		c3.toggle_mode = true
		c3.button_group = pg
		c3.set_pressed_no_signal(i == int(Store.getv("palette")))
		var pi := i
		c3.pressed.connect(func() -> void:
				Store.setv("palette", pi))
		pal_row.add_child(c3)
		_pal_chips[i] = c3
	opt.add_child(pal_row)
	body.add_child(W.card([opt], 14))

	body.add_child(W.primary("QR Kodu Oluştur", func() -> void:
			_generate()))

	# Sonuç alanı
	_result_box = W.vbox([], 12)
	_result_box.visible = false
	body.add_child(_result_box)

	body.add_child(W.gap(8))
	add_child(W.scroll(body))


func _set_type(key: String) -> void:
	_type = key
	for k in _type_chips:
		_type_chips[k].set_pressed_no_signal(k == key)
	_build_form()
	_hide_result()


func _sync_ecc() -> void:
	var lvl := str(Store.getv("ecc"))
	for k in _ecc_chips:
		_ecc_chips[k].set_pressed_no_signal(k == lvl)
	if _ecc_hint:
		_ecc_hint.text = str(ECC_INFO.get(lvl, ""))


func _build_form() -> void:
	for ch in _form_box.get_children():
		_form_box.remove_child(ch)
		ch.queue_free()
	_fields.clear()
	for spec in FORMS[_type]:
		var title: String = spec[0]
		var key: String = spec[1]
		var ph: String = spec[2]
		var kind: String = spec[3]
		match kind:
			"line":
				var e := LineEdit.new()
				e.placeholder_text = ph
				e.custom_minimum_size = Vector2(0, 48)
				_fields[key] = e
				_form_box.add_child(W.vbox([W.label(title, "SectionLabel", 13, true), e], 6))
			"text":
				var te := TextEdit.new()
				te.placeholder_text = ph
				te.custom_minimum_size = Vector2(0, 110)
				te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_fields[key] = te
				_form_box.add_child(W.vbox([W.label(title, "SectionLabel", 13, true), te], 6))
			"select":
				var ob := OptionButton.new()
				for item in spec[4]:
					ob.add_item(item)
				ob.custom_minimum_size = Vector2(0, 48)
				_fields[key] = ob
				_form_box.add_child(W.vbox([W.label(title, "SectionLabel", 13, true), ob], 6))
			"check":
				var cb := CheckButton.new()
				cb.text = title
				_fields[key] = cb
				_form_box.add_child(cb)


func refresh() -> void:
	_sync_ecc()
	for i in _pal_chips:
		_pal_chips[i].set_pressed_no_signal(i == int(Store.getv("palette")))


func on_retheme() -> void:
	pass


# --- Üretim -----------------------------------------------------------------

func _s(v: Dictionary, key: String) -> String:
	return str(v.get(key, "")).strip_edges()


func _collect() -> Dictionary:
	var out := {}
	for k in _fields:
		var c: Control = _fields[k]
		if c is LineEdit:
			out[k] = (c as LineEdit).text
		elif c is TextEdit:
			out[k] = (c as TextEdit).text
		elif c is OptionButton:
			out[k] = (c as OptionButton).selected
		elif c is CheckButton:
			out[k] = (c as CheckButton).button_pressed
	return out


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "payload": "", "title": ""}


func _make_payload(v: Dictionary) -> Dictionary:
	match _type:
		"url":
			var u := _s(v, "url")
			if u == "":
				return _err("Adres girin")
			var built := Payload.build_url(u)
			return {"ok": true, "error": "", "payload": built, "title": Payload.host_of(built)}
		"text":
			var t := _s(v, "text")
			if t == "":
				return _err("Metin girin")
			return {"ok": true, "error": "", "payload": t, "title": t.get_slice("\n", 0)}
		"wifi":
			var ssid := _s(v, "ssid")
			if ssid == "":
				return _err("Ağ adı (SSID) girin")
			var sec_idx := int(v.get("sec", 0))
			var sec: String = ["WPA", "WEP", "nopass"][clampi(sec_idx, 0, 2)]
			var hidden := bool(v.get("hidden", false))
			return {
				"ok": true, "error": "", "title": ssid,
				"payload": Payload.build_wifi(ssid, _s(v, "wpass"), sec, hidden),
			}
		"contact":
			var cname := _s(v, "name")
			if cname == "":
				return _err("Ad soyad girin")
			return {
				"ok": true, "error": "", "title": cname,
				"payload": Payload.build_contact(cname, _s(v, "org"), _s(v, "tel"), _s(v, "mail"), _s(v, "web"), _s(v, "adr")),
			}
		"phone":
			var num := _s(v, "num")
			if num == "":
				return _err("Telefon numarası girin")
			return {"ok": true, "error": "", "payload": Payload.build_phone(num), "title": num}
		"sms":
			var snum := _s(v, "num")
			if snum == "":
				return _err("Numara girin")
			return {"ok": true, "error": "", "payload": Payload.build_sms(snum, str(v.get("msg", ""))), "title": snum}
		"email":
			var to := _s(v, "to")
			if to == "":
				return _err("Alıcı girin")
			return {
				"ok": true, "error": "", "title": to,
				"payload": Payload.build_email(to, _s(v, "subject"), str(v.get("body", ""))),
			}
		"location":
			var lat := _s(v, "lat")
			var lon := _s(v, "lon")
			if not lat.is_valid_float() or not lon.is_valid_float():
				return _err("Enlem ve boylam sayı olmalı (ör. 41.0082)")
			if absf(float(lat)) > 90.0 or absf(float(lon)) > 180.0:
				return _err("Koordinat aralığı dışında (enlem ±90, boylam ±180)")
			return {
				"ok": true, "error": "",
				"payload": Payload.build_geo(lat, lon),
				"title": "%s, %s" % [lat, lon],
			}
		"event":
			var etitle := _s(v, "title")
			if etitle == "":
				return _err("Etkinlik başlığı girin")
			var ev := Payload.build_event(etitle, _s(v, "loc"), _s(v, "date"), _s(v, "time"), _s(v, "edate"), _s(v, "etime"))
			if not ev.contains("DTSTART:"):
				return _err("Tarih formatı şu olmalı: 2026-10-02")
			return {"ok": true, "error": "", "payload": ev, "title": etitle}
	return _err("Bilinmeyen tür")


func _generate() -> void:
	var res := _make_payload(_collect())
	if not bool(res.get("ok", false)):
		app.toast(str(res.get("error", "")))
		return
	var payload := str(res["payload"])
	var qr := QrGen.new()
	var ecl := QrGen.ecc_from_name(str(Store.getv("ecc")))
	if not qr.encode_text(payload, ecl):
		app.toast("İçerik çok uzun — metni kısaltın veya hata düzeltmeyi düşürün")
		return
	var pal_idx := clampi(int(Store.getv("palette")), 0, PALETTES.size() - 1)
	var img: Image = qr.to_image(8, 4, PALETTES[pal_idx][1], Color.WHITE)
	if img == null:
		app.toast("Kod oluşturulamadı")
		return
	var tex := ImageTexture.create_from_image(img)
	_last_texture = tex
	_last_payload = payload
	_last_meta = "Seviye %s · Sürüm %d · %d×%d modül" % [str(Store.getv("ecc")), qr.version, qr.size, qr.size]
	Store.add_entry("gen", _type, payload, str(res.get("title", "")))
	app.refresh_all()
	_show_result()


func _hide_result() -> void:
	_last_texture = null
	_last_payload = ""
	if _result_box:
		for ch in _result_box.get_children():
			_result_box.remove_child(ch)
			ch.queue_free()
		_result_box.visible = false


func _show_result() -> void:
	for ch in _result_box.get_children():
		_result_box.remove_child(ch)
		ch.queue_free()
	_result_box.visible = true

	var v := W.vbox([], 12)
	v.add_child(W.label("QR KODUNUZ", "SectionLabel", 11, true))

	var tr := TextureRect.new()
	tr.texture = _last_texture
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(0, 292)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(tr)

	v.add_child(W.wrap(_last_meta, "MutedLabel", 12))

	var pv := TextEdit.new()
	pv.editable = false
	pv.text = _last_payload
	pv.custom_minimum_size = Vector2(0, 64)
	pv.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(pv)

	var r1 := W.hbox([], 8)
	var save_btn := W.secondary("Galeriye Kaydet", _save_png)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(save_btn)
	var share_btn := W.secondary("Paylaş", _share_png)
	share_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(share_btn)
	v.add_child(r1)

	var r2 := W.hbox([], 8)
	var copy_btn := W.secondary("Kopyala", func() -> void:
			DisplayServer.clipboard_set(_last_payload)
			app.toast("Kod içeriği kopyalandı"))
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(copy_btn)
	var new_btn := W.primary("Yeni Kod", func() -> void:
			_hide_result())
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(new_btn)
	v.add_child(r2)

	_result_box.add_child(W.card([v], 14))
	_scroll_to_result()


func _scroll_to_result() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var sc := get_child(0) as ScrollContainer
	if sc:
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _export_png() -> String:
	if _last_texture == null:
		return ""
	var img := _last_texture.get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
	var path := "user://exports/qr_%d.png" % int(Time.get_unix_time_from_system())
	if img.save_png(path) != OK:
		return ""
	return ProjectSettings.globalize_path(path)


func _save_png() -> void:
	var path := _export_png()
	if path == "":
		app.toast("PNG kaydedilemedi")
		return
	var r := Native.save_image_to_gallery(path)
	if bool(r.get("ok", false)):
		app.toast("Galeriye kaydedildi")
	else:
		app.toast(str(r.get("message", "Kaydedilemedi")))


func _share_png() -> void:
	var path := _export_png()
	if path == "":
		app.toast("PNG oluşturulamadı")
		return
	Native.share_file(path, "image/png")
## >>> CREATE_END <<<
