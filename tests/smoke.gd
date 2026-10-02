extends SceneTree
## Headless duman testi: `godot --headless -s res://tests/smoke.gd`
## Sahne kurulumu + ekranlar + modal + QR üretim + geçmiş akışlarını sınar.
## Not: -s modunda autoload adları derleme anında görünmeyebildiği için
## Store'a /root/Store üzerinden erişilir.

var fails := 0
var checks := 0
var store: Node = null


func _check(name: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("PASS  ", name)
	else:
		fails += 1
		print("FAIL  ", name)


func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_check("main.tscn yüklendi", packed != null)
	var app: Control = packed.instantiate()
	root.add_child(app)
	await _run(app)


func _run(app: Control) -> void:
	await process_frame
	await process_frame
	store = root.get_node("/root/Store")
	_check("Store autoload", store != null)

	_check("tema kuruldu", app.theme != null)
	_check("4 sekme", app.screens.size() == 4)

	# Sekmeleri dolaş
	for i in 4:
		app._select_tab(i)
		await process_frame
		_check("sekme %d görünür" % i, app.screens[i].visible)
	app._select_tab(0)

	# Plugin yokken tarama denemesi → sessiz uyarı
	app.start_scan(false)
	await process_frame

	# Geçmiş + sonuç modalı
	var entry: Dictionary = store.add_entry("scan", "url", "https://example.com/test", "example.com")
	_check("geçmiş kaydı", not entry.is_empty())
	app.show_result(entry)
	await process_frame
	_check("modal açıldı", app._modal_open())
	app._close_modal()
	_check("modal kapandı", not app._modal_open())

	# Riskli URL modalı
	var bad: Dictionary = store.add_entry("scan", "url", "https://xn--gl-1a.example.com/a@b", "phish")
	app.show_result(bad)
	await process_frame
	_check("riskli URL modalı", app._modal_open())
	app._close_modal()

	# Onay diyaloğu
	app.confirm("Test", "Mesaj", func() -> void:
			print("confirm cb çalıştı"))
	await process_frame
	app._confirm_accept()

	# QR üretimi — doğru referans sha256 (python qrcodegen ile karşılaştırılır)
	var cases := {
		"C1": ["HELLO WORLD", QrGen.Ecc.MEDIUM],
		"C2": ["https://example.com/some/path?q=123", QrGen.Ecc.HIGH],
		"C3": ["12345678901234567890", QrGen.Ecc.LOW],
		"C4": ["İstanbul Boğaziçi ığdır şçöü ĞÜŞİ", QrGen.Ecc.QUARTILE],
		"C5": ["A".repeat(300), QrGen.Ecc.MEDIUM],
		"C6": ["BEGIN:VCARD\nVERSION:3.0\nN:Yılmaz;Ayşe;;;\nFN:Ayşe Yılmaz\nTEL;TYPE=CELL:+905551234567\nEND:VCARD", QrGen.Ecc.MEDIUM],
	}
	for k in cases:
		var qr := QrGen.new()
		var text: String = cases[k][0]
		var ecl: int = cases[k][1]
		var ok := qr.encode_text(text, ecl)
		_check("qr %s üretildi" % k, ok)
		if ok:
			var bits := ""
			for y in qr.size:
				for x in qr.size:
					bits += "1" if qr.modules[y * qr.size + x] == 1 else "0"
			print("QRCASE|", k, "|", qr.version, "|", bits.sha256_text())
			var img: Image = qr.to_image(4, 4)
			_check("qr %s görüntü" % k, img != null and img.get_width() > (qr.size * 4))

	# Çok uzun veri → false
	var qr_long := QrGen.new()
	_check("aşırı uzun veri reddedildi", not qr_long.encode_text("A".repeat(6000), QrGen.Ecc.HIGH))

	# Payload sınıflandırma
	_check("wifi sınıfı", Payload.classify("WIFI:T:WPA;S:Ev;P:1234;;")["type"] == "wifi")
	_check("vcard sınıfı", Payload.classify("BEGIN:VCARD\nVERSION:3.0\nEND:VCARD")["type"] == "contact")
	_check("url sınıfı", Payload.classify("https://a.com")["type"] == "url")
	_check("düz metin", Payload.classify("merhaba dünya")["type"] == "text")
	_check("şüpheli URL", Payload.is_suspicious_url("http://google.com@evil.test/x"))
	_check("güvenli URL", not Payload.is_suspicious_url("https://google.com/x"))
	_check("wifi üretimi", Payload.build_wifi("Ev", "sifre", "WPA", false).contains("S:Ev;"))
	_check("vcard üretimi", Payload.build_contact("Ayşe Yılmaz", "", "", "", "", "").contains("FN:Ayşe Yılmaz"))
	_check("geo doğrulama", Payload.build_geo("41.0", "29.0") == "geo:41.0,29.0")

	# CSV
	var csv: String = store.export_csv()
	_check("csv başlık", csv.begins_with("id,kind,type"))
	_check("csv satır", csv.split("\n").size() >= 2)

	# Tema geçişi
	store.setv("theme", "light")
	await process_frame
	_check("açık tema", not store.is_dark())
	store.setv("theme", "dark")
	await process_frame
	_check("koyu tema", store.is_dark())

	# Geçmiş filtreleri
	_check("arama filtresi", store.query("example", "scan").size() >= 1)
	_check("favori filtresi", store.query("", "fav").size() == 0)
	store.toggle_fav(str(entry.get("id", "")))
	_check("favori eklendi", store.query("", "fav").size() == 1)
	store.clear_history()
	_check("geçmiş temizlendi", store.history().is_empty())

	# Ayarlar kalıcılığı
	store.setv("ecc", "H")
	_check("ecc kaydedildi", str(store.getv("ecc")) == "H")
	store.setv("ecc", "M")

	await process_frame
	print("SONUC|", checks - fails, "/", checks, " geçti, ", fails, " başarısız")
	quit(1 if fails > 0 else 0)
