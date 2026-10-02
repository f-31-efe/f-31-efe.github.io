class_name Payload
extends RefCounted
## Üretilen/taranan içeriklerin sınıflandırılması, etiketlenmesi ve
## standart QR yüklerinin (Wi‑Fi, vCard, SMS, ...) üretilmesi.

const SAFE_SCHEMES := ["http", "https", "mailto", "tel", "sms", "geo", "market", "whatsapp"]
const UNSAFE_SCHEMES := ["javascript", "file", "data", "intent", "content", "vbscript", "ftp"]


## Taranan/metin içeriğinden tür ve başlık çıkarır.
static func classify(text: String) -> Dictionary:
	var t := text.strip_edges()
	var lower := t.to_lower()

	if lower.begins_with("http://") or lower.begins_with("https://"):
		return {"type": "url", "title": _host_of(t), "openable": true, "needs_preview": true}
	if lower.begins_with("begin:vcard"):
		return {"type": "contact", "title": _vcard_name(t), "openable": false, "needs_preview": false}
	if lower.begins_with("begin:vevent"):
		return {"type": "event", "title": _ini_value(t, "SUMMARY", "Etkinlik"), "openable": false, "needs_preview": false}
	if lower.begins_with("wifi:"):
		return {"type": "wifi", "title": _wifi_ssid(t), "openable": false, "needs_preview": false}
	if lower.begins_with("mailto:"):
		return {"type": "email", "title": t.substr(7).split("?")[0], "openable": true, "needs_preview": false}
	if lower.begins_with("smsto:") or lower.begins_with("sms:"):
		return {"type": "sms", "title": t.get_slice(":", 1), "openable": true, "needs_preview": false}
	if lower.begins_with("tel:"):
		return {"type": "phone", "title": t.substr(4), "openable": true, "needs_preview": false}
	if lower.begins_with("geo:"):
		return {"type": "location", "title": t.substr(4), "openable": true, "needs_preview": false}
	if lower.begins_with("market://") or lower.begins_with("market:"):
		return {"type": "app", "title": t.get_slice("/", 3), "openable": true, "needs_preview": false}
	if lower.begins_with("mecard:"):
		return {"type": "contact", "title": "Kişi kartı", "openable": false, "needs_preview": false}
	return {"type": "text", "title": _first_line(t), "openable": false, "needs_preview": false}


static func type_label(t: String) -> String:
	match t:
		"url":
			return "WEB BAĞLANTISI"
		"wifi":
			return "WI‑FI AĞI"
		"contact":
			return "KİŞİ KARTI"
		"event":
			return "ETKİNLİK"
		"email":
			return "E‑POSTA"
		"sms":
			return "SMS"
		"phone":
			return "TELEFON"
		"location":
			return "KONUM"
		"text":
			return "METİN"
		"app":
			return "UYGULAMA"
	return "KOD"


static func can_open(text: String) -> bool:
	var scheme := text.get_slice(":", 0).to_lower()
	if text.contains("://") or ["mailto", "tel", "sms", "geo", "market"].has(scheme):
		return scheme in SAFE_SCHEMES
	return false


## Güvenli (yalnızca http/https) bağlantıyı kullanıcıya göstermek için.
static func host_of(url: String) -> String:
	return _host_of(url)


static func is_suspicious_url(url: String) -> bool:
	var lower := url.to_lower()
	var scheme := url.get_slice(":", 0).to_lower()
	if scheme != "https" and scheme != "http":
		return true
	if lower.contains("@"):  # kimlik dolandırıcılığı: http://google.com@evil.com
		return true
	if lower.contains("xn--"):  # punycode / homograf
		return true
	var host := _host_of(url)
	# IP adresiyle barındırılan bağlantılar
	if host.match("*.*.*.*"):
		return true
	if host.count(".") > 4:
		return true
	return false


# --- Üretici (payload builders) ----------------------------------------------

static func build_url(url: String) -> String:
	var u := url.strip_edges()
	if not (u.to_lower().begins_with("http://") or u.to_lower().begins_with("https://")):
		u = "https://" + u
	return u


static func build_wifi(ssid: String, password: String, security: String, hidden: bool) -> String:
	var s := "WPA" if security == "WPA" else ("WEP" if security == "WEP" else "nopass")
	var out := "WIFI:T:%s;S:%s;" % [s, _escape_wifi(ssid)]
	if s != "nopass":
		out += "P:%s;" % _escape_wifi(password)
	if hidden:
		out += "H:true;"
	return out + ";"


static func _escape_wifi(v: String) -> String:
	return v.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace(":", "\\:")


static func build_contact(full_name: String, org: String, phone: String, email: String, url: String, address: String) -> String:
	var parts := full_name.strip_edges().split(" ", false)
	var last := ""
	var first := full_name.strip_edges()
	if parts.size() > 1:
		last = parts[parts.size() - 1]
		first = " ".join(parts.slice(0, parts.size() - 1))
	var lines := [
		"BEGIN:VCARD",
		"VERSION:3.0",
		"N:%s;%s;;;" % [last, first],
		"FN:%s" % full_name.strip_edges(),
	]
	if org.strip_edges() != "":
		lines.append("ORG:%s" % org.strip_edges())
	if phone.strip_edges() != "":
		lines.append("TEL;TYPE=CELL:%s" % phone.strip_edges())
	if email.strip_edges() != "":
		lines.append("EMAIL;TYPE=INTERNET:%s" % email.strip_edges())
	if url.strip_edges() != "":
		lines.append("URL:%s" % url.strip_edges())
	if address.strip_edges() != "":
		lines.append("ADR;TYPE=HOME:;;%s;;;;" % address.strip_edges())
	lines.append("END:VCARD")
	return "\n".join(lines)


static func build_phone(number: String) -> String:
	return "tel:%s" % number.strip_edges().replace(" ", "")


static func build_sms(number: String, message: String) -> String:
	return "SMSTO:%s:%s" % [number.strip_edges().replace(" ", ""), message]


static func build_email(to: String, subject: String, body: String) -> String:
	var out := "mailto:%s" % to.strip_edges()
	var q := []
	if subject.strip_edges() != "":
		q.append("subject=" + subject.strip_edges().uri_encode())
	if body != "":
		q.append("body=" + body.uri_encode())
	if not q.is_empty():
		out += "?" + "&".join(q)
	return out


static func build_geo(lat: String, lon: String) -> String:
	return "geo:%s,%s" % [lat.strip_edges(), lon.strip_edges()]


## Tarih "2026-10-02", saat "14:30" → vEvent DTSTART (yerel saat)
static func build_event(title: String, location: String, date: String, time: String, end_date: String, end_time: String) -> String:
	var dt := _compact_datetime(date, time)
	var lines := [
		"BEGIN:VEVENT",
		"SUMMARY:%s" % title.strip_edges(),
	]
	if location.strip_edges() != "":
		lines.append("LOCATION:%s" % location.strip_edges())
	if dt != "":
		lines.append("DTSTART:%s" % dt)
		var et := _compact_datetime(end_date, end_time)
		if et != "":
			lines.append("DTEND:%s" % et)
	lines.append("END:VEVENT")
	return "\n".join(lines)


static func _compact_datetime(date: String, time: String) -> String:
	var d := date.strip_edges().replace("-", "").replace("/", "")
	var t := time.strip_edges().replace(":", "")
	if d.length() == 8 and d.is_valid_int():
		if t.length() == 4 and t.is_valid_int():
			return d + "T" + t + "00"
		return d + "T090000"
	return ""


# --- Yardımcılar ---------------------------------------------------------------

static func _host_of(url: String) -> String:
	var u := url
	if u.to_lower().begins_with("http://"):
		u = u.substr(7)
	elif u.to_lower().begins_with("https://"):
		u = u.substr(8)
	u = u.get_slice("/", 0)
	u = u.get_slice("?", 0)
	u = u.get_slice("#", 0)
	if u.contains("@"):
		u = u.get_slice("@", 1)
	return u


static func _first_line(t: String) -> String:
	var line := t.get_slice("\n", 0)
	if line.length() > 60:
		return line.substr(0, 57) + "..."
	return line


static func _ini_value(text: String, key: String, fallback: String) -> String:
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.to_upper().begins_with(key + ":"):
			return line.substr(key.length() + 1).strip_edges()
	return fallback


static func _vcard_name(text: String) -> String:
	var fn := _ini_value(text, "FN", "")
	if fn != "":
		return fn
	var n := _ini_value(text, "N", "")
	var parts := n.split(";")
	if parts.size() >= 2 and (parts[0] != "" or parts[1] != ""):
		return (parts[1] + " " + parts[0]).strip_edges()
	return "Kişi kartı"


static func _wifi_ssid(text: String) -> String:
	var body := text.substr(5)
	for pair in body.split(";"):
		if pair.to_lower().begins_with("s:"):
			return pair.substr(2).replace("\\,", ",").replace("\\;", ";").replace("\\:", ":")
	return "Wi‑Fi ağı"
