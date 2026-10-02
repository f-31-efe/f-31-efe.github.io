extends Node
## Store — ayarlar (user://settings.cfg) ve tarama/geçmiş verisi (user://history.json).
## Tüm veriler cihazda kalır; hiçbir şey ağa gönderilmez.

signal changed(key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const HISTORY_PATH := "user://history.json"

const DEFAULTS := {
	"theme": "system",        # system | dark | light
	"sound": true,            # taramada bip sesi
	"vibrate": true,          # taramada titreşim
	"auto_copy": false,       # taranan içeriği panoya kopyala
	"url_preview": true,      # açmadan önce URL güvenlik önizlemesi
	"auto_open": false,       # tarar tarar açma (önerilmez, önizleme ile)
	"continuous": false,      # sürekli/toplu tarama
	"save_history": true,     # geçmişi kaydet
	"history_limit": 500,
	"ecc": "M",               # QR hata düzeltme seviyesi L/M/Q/H
	"palette": 0,             # QR renk paleti indeksi
	"scan_sessions": 0,       # reklam sıklığı sayacı
	"interstitial_every": 3,  # her N tarama oturumunda bir ara reklam
	"privacy_url": "",        # Play Store gizlilik bağlantısı
	"csv_delimiter": ",",
}

var _settings: Dictionary = {}
var _history: Array = []
var _dirty := false


func _ready() -> void:
	_load_settings()
	_load_history()


# --- Ayarlar -------------------------------------------------------------

func getv(key: String) -> Variant:
	if _settings.has(key):
		return _settings[key]
	return DEFAULTS.get(key)


func setv(key: String, value: Variant) -> void:
	_settings[key] = value
	_save_settings()
	changed.emit(key, value)


func is_dark() -> bool:
	var mode := str(getv("theme"))
	if mode == "dark":
		return true
	if mode == "light":
		return false
	# system: cihapın karanlık modu
	return _system_dark()


func _system_dark() -> bool:
	if DisplayServer.is_dark_mode_supported():
		return DisplayServer.is_dark_mode()
	return true


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		_settings = DEFAULTS.duplicate()
		return
	for k in DEFAULTS.keys():
		if cf.has_section_key("settings", k):
			_settings[k] = cf.get_value("settings", k)
		else:
			_settings[k] = DEFAULTS[k]


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in _settings.keys():
		cf.set_value("settings", k, _settings[k])
	cf.save(SETTINGS_PATH)


# --- Geçmiş ---------------------------------------------------------------

func history() -> Array:
	return _history


func add_entry(kind: String, type: String, content: String, title := "", extra: Dictionary = {}) -> Dictionary:
	if not bool(getv("save_history")):
		return {}
	# Aynı içerik art arda tarandıysa tekleştir (sürekli taramada spam önleme)
	if not _history.is_empty():
		var last: Dictionary = _history[0]
		if last.get("content", "") == content and last.get("kind", "") == kind:
			last["ts"] = int(Time.get_unix_time_from_system())
			_save_history()
			return last

	var entry := {			"id": "%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"kind": kind,            # "scan" | "gen"
		"type": type,            # url | wifi | text | contact | ...
		"content": content,
		"title": title,
		"ts": int(Time.get_unix_time_from_system()),
		"fav": false,
		"extra": extra,
	}
	_history.push_front(entry)

	var limit := int(getv("history_limit"))
	while _history.size() > limit:
		_history.pop_back()
	_save_history()
	return entry


func remove_entry(id: String) -> void:
	for i in _history.size():
		if str(_history[i].get("id", "")) == id:
			_history.remove_at(i)
			_save_history()
			return


func toggle_fav(id: String) -> void:
	for e in _history:
		if str(e.get("id", "")) == id:
			e["fav"] = not bool(e.get("fav", false))
			_save_history()
			return


func clear_history() -> void:
	_history.clear()
	_save_history()


func find_entry(id: String) -> Dictionary:
	for e in _history:
		if str(e.get("id", "")) == id:
			return e
	return {}


## Filtre: search metin araması, filter = all|scan|gen|fav
func query(search := "", filter := "all") -> Array:
	var out := []
	var s := search.strip_edges().to_lower()
	for e in _history:
		if filter == "scan" and e.get("kind") != "scan":
			continue
		if filter == "gen" and e.get("kind") != "gen":
			continue
		if filter == "fav" and not bool(e.get("fav", false)):
			continue
		if s != "":
			var hay := (str(e.get("content", "")) + " " + str(e.get("title", ""))).to_lower()
			if not hay.contains(s):
				continue
		out.append(e)
	return out


func _load_history() -> void:
	if not FileAccess.file_exists(HISTORY_PATH):
		_history = []
		return
	var f := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if f == null:
		_history = []
		return
	var parsed = JSON.parse_string(f.get_as_text())
	_history = parsed if parsed is Array else []


func _save_history() -> void:
	var f := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Geçmiş dosyası yazılamadı: " + HISTORY_PATH)
		return
	f.store_string(JSON.stringify(_history))


# --- Dışa aktarma ---------------------------------------------------------

const CSV_HEADER := "id,kind,type,title,content,timestamp,favorite"

func export_csv() -> String:
	var delim := str(getv("csv_delimiter"))
	var lines := [CSV_HEADER]
	for e in _history:
		var ts := Time.get_datetime_string_from_unix_time(int(e.get("ts", 0)), false)
		var cells := PackedStringArray([
			_csv_cell(str(e.get("id", "")), delim),
			_csv_cell(str(e.get("kind", "")), delim),
			_csv_cell(str(e.get("type", "")), delim),
			_csv_cell(str(e.get("title", "")), delim),
			_csv_cell(str(e.get("content", "")), delim),
			ts,
			"1" if bool(e.get("fav", false)) else "0",
		])
		lines.append(delim.join(cells))
	return "\n".join(lines)


func _csv_cell(v: String, delim: String) -> String:
	if v.contains(delim) or v.contains("\"") or v.contains("\n"):
		return "\"" + v.replace("\"", "\"\"") + "\""
	return v
