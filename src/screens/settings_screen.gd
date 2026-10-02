class_name SettingsScreen
extends MarginContainer
## Ayarlar sekmesi: tarama, güvenlik, görünüm, veri ve hakkında.

const PRIVACY_TEXT := """QR Master kamera görüntüsünü işler, kodu okur ve kapatır.
• Tarama sonuçları yalnızca bu cihazda saklanır.
• Uygulama hesap gerektirmez, veri toplamaz ve paylaşmaz.
• Kamera izni yalnızca kod taramak için istenir.
• Reklamlar Google AdMob tarafından sunulur; reklam sağlayıcıları
  reklam kimliğiyle ilgili veriler toplayabilir.
• Geçmiş verileri istediğiniz zaman silebilirsiniz."""

var app: Control
var _theme_chips: Dictionary = {}
var _limit_option: OptionButton
var _theme_row_chips: Dictionary = {}


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
	head.add_child(W.label("Ayarlar", "H1Label", 30, true))
	head.add_child(W.wrap("Tarama, güvenlik ve veri tercihleri.", "MutedLabel", 15))
	body.add_child(head)

	# TARAMA
	body.add_child(W.section("Tarama"))
	var scan_card := W.vbox([], 6)
	scan_card.add_child(_toggle("Sürekli tarama", "Ardışık kodları duraklatmadan okur.", "continuous"))
	scan_card.add_child(_divider_row())
	scan_card.add_child(_toggle("Bip sesi", "Kod bulununca kısa ses çalar.", "sound"))
	scan_card.add_child(_divider_row())
	scan_card.add_child(_toggle("Titreşim", "Kod bulununca cihaz titrer.", "vibrate"))
	scan_card.add_child(_divider_row())
	scan_card.add_child(_toggle("Panoya otomatik kopyala", "Taranan içeriği panoya kopyalar.", "auto_copy"))
	body.add_child(W.card([scan_card], 8))

	# GÜVENLİK
	body.add_child(W.section("Güvenlik"))
	var sec_card := W.vbox([], 6)
	sec_card.add_child(_toggle(
		"Bağlantı önizlemesi",
		"Açmadan önce hedef adres ve risk uyarıları gösterilir (önerilir).",
		"url_preview"))
	sec_card.add_child(_divider_row())
	sec_card.add_child(_toggle(
		"Otomatik aç (güvenli bağlantılar)",
		"Önizleme kapalıyken güvenli http/https bağlantılarını hemen açar. Riskli adresler yine de sorar.",
		"auto_open"))
	body.add_child(W.card([sec_card], 8))

	# GÖRÜNÜM
	body.add_child(W.section("Görünüm"))
	var theme_flow := HFlowContainer.new()
	theme_flow.add_theme_constant_override("h_separation", 8)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var modes := [["system", "Sistem"], ["dark", "Koyu"], ["light", "Açık"]]
	for m in modes:
		var c := W.chip(m[1])
		c.toggle_mode = true
		c.button_group = group
		c.set_pressed_no_signal(str(Store.getv("theme")) == m[0])
		var key: String = m[0]
		c.pressed.connect(func() -> void:
				Store.setv("theme", key)
				_sync_theme_chips())
		theme_flow.add_child(c)
		_theme_chips[key] = c
	body.add_child(W.card([theme_flow], 10))

	# VERİ
	body.add_child(W.section("Veri"))
	var data_card := W.vbox([], 6)
	data_card.add_child(_toggle("Geçmişi kaydet", "Tarama ve üretim kayıtları cihazda tutulur.", "save_history"))
	data_card.add_child(_divider_row())

	_limit_option = OptionButton.new()
	for n in [100, 250, 500, 1000]:
		_limit_option.add_item(str(n))
	_limit_option.select(maxi(0, [100, 250, 500, 1000].find(int(Store.getv("history_limit")))))
	_limit_option.custom_minimum_size = Vector2(0, 48)
	_limit_option.item_selected.connect(func(idx: int) -> void:
			var vals := [100, 250, 500, 1000]
			Store.setv("history_limit", vals[idx]))
	data_card.add_child(W.vbox([
		W.label("Geçmiş kayıt limiti", "SectionLabel", 13, true),
		_limit_option,
	], 6))
	data_card.add_child(_divider_row())
	var csv_btn := W.secondary("Geçmişi CSV olarak paylaş", func() -> void:
			app.export_csv())
	data_card.add_child(csv_btn)
	var clear_btn := W.danger("Tüm geçmişi sil", func() -> void:
			app.confirm(
				"Geçmişi Sil",
				"Tüm kayıtlar kalıcı olarak silinecek. Bu işlem geri alınamaz.",
				_clear_confirmed))
	data_card.add_child(clear_btn)
	body.add_child(W.card([data_card], 8))

	# HAKKINDA
	body.add_child(W.section("Hakkında"))
	var about := W.vbox([], 6)
	about.add_child(W.wrap("QR Master · Sürüm %s" % app.APP_VERSION, "", 15))
	about.add_child(W.wrap("Silvia Games — verileriniz cihazınızda kalır, hesap gerekmez.", "MutedLabel", 13))
	var privacy_btn := W.secondary("Gizlilik Özeti", func() -> void:
			_show_privacy())
	about.add_child(privacy_btn)
	var purl := str(Store.getv("privacy_url")).strip_edges()
	if purl != "":
		var plink := W.ghost("Çevrimiçi gizlilik politikası", func() -> void:
				Native.open_uri(purl))
		about.add_child(plink)
	about.add_child(W.wrap("Uygulama ücretsizdir ve reklamlarla desteklenir.", "MutedLabel", 12))
	body.add_child(W.card([about], 8))

	body.add_child(W.gap(10))
	add_child(W.scroll(body))


func _toggle(title: String, desc: String, key: String) -> Control:
	var row := W.toggle_row(title, desc, bool(Store.getv(key)), func(v: bool) -> void:
			Store.setv(key, v))
	return row


func _divider_row() -> Control:
	return W.divider()


func _clear_confirmed() -> void:
	Store.clear_history()
	app.toast("Geçmiş temizlendi")


func _sync_theme_chips() -> void:
	var cur := str(Store.getv("theme"))
	for k in _theme_chips:
		_theme_chips[k].set_pressed_no_signal(k == cur)


func _show_privacy() -> void:
	var body := W.vbox([], 8)
	body.add_child(W.wrap(PRIVACY_TEXT, "MutedLabel", 14))
	var close_row := W.hbox([], 8)
	var ok := W.primary("Anladım", func() -> void:
			app._close_modal())
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(ok)
	body.add_child(close_row)
	app._present_modal("Gizlilik", body, 0.88)


func refresh() -> void:
	_sync_theme_chips()
	if _limit_option:
		_limit_option.select(maxi(0, [100, 250, 500, 1000].find(int(Store.getv("history_limit")))))


func on_retheme() -> void:
	pass
