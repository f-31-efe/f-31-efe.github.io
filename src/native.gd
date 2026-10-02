extends Node
## Native — Godot↔Android köprüsü (SvQrScanner eklentisi).
## Eklenti yoksa (editör/masaüstü) tüm çağrılar sessizce devre dışı kalır;
## uygulama yine de üretme/geçmiş özelliklerini kullanabilir.

signal event(e: Dictionary)

const PLUGIN_NAME := "SvQrScanner"

var _plugin: Object = null
var _poll: Timer = null


func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		_poll = Timer.new()
		_poll.wait_time = 0.15
		_poll.autostart = true
		_poll.timeout.connect(_drain)
		add_child(_poll)
	else:
		print("[Native] ", PLUGIN_NAME, " eklentisi yok — tarama/oglasyon özellikleri kapalı (editör mü?)")


func available() -> bool:
	return _plugin != null


func _drain() -> void:
	if _plugin == null:
		return
	var raw: String = _plugin.pollEvents()
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if not (parsed is Array):
		return
	for e in parsed:
		if e is Dictionary:
			event.emit(e)


# --- Tarama ---------------------------------------------------------------

func start_scan(opts: Dictionary = {}) -> void:
	if _plugin:
		_plugin.startScan(JSON.stringify(opts))


func stop_scan() -> void:
	if _plugin:
		_plugin.stopScan()


# --- Sistem eylemleri -----------------------------------------------------

func open_uri(uri: String) -> bool:
	if _plugin:
		return bool(_plugin.openUri(uri))
	# Masaüstü/geçici çözüm
	return OS.shell_open(uri) == OK


func share_text(text: String, mime := "text/plain") -> void:
	if _plugin:
		_plugin.shareText(text, mime)


func share_file(path: String, mime: String) -> void:
	if _plugin:
		_plugin.shareFile(path, mime)


func save_image_to_gallery(path: String) -> Dictionary:
	if _plugin:
		var r = _plugin.saveImageToGallery(path)
		if r is String and not r.is_empty():
			var parsed = JSON.parse_string(r)
			if parsed is Dictionary:
				return parsed
		return {"ok": true}
	return {"ok": false, "message": "Bu özellik Android uygulamasında kullanılabilir."}


func beep() -> void:
	if _plugin:
		_plugin.playBeep()


func vibrate(ms := 35) -> void:
	if Store.getv("vibrate"):
		Input.vibrate_handheld(ms)


# --- Reklamlar (AdMob) ----------------------------------------------------

## Test reklam birimleri — production için README'deki AdMob ID'leriyle değiştirin.
const TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"

var ads_ready := false

func init_ads(banner_id := TEST_BANNER, interstitial_id := TEST_INTERSTITIAL) -> void:
	if _plugin and not ads_ready:
		_plugin.initAds(banner_id, interstitial_id)
		ads_ready = true


func banner_height() -> int:
	if _plugin and ads_ready:
		return int(_plugin.bannerHeightPx())
	return 0


func show_banner() -> void:
	if _plugin and ads_ready:
		_plugin.showBanner()


func hide_banner() -> void:
	if _plugin and ads_ready:
		_plugin.hideBanner()


func load_interstitial() -> void:
	if _plugin and ads_ready:
		_plugin.loadInterstitial()


func show_interstitial() -> bool:
	if _plugin and ads_ready:
		return bool(_plugin.showInterstitial())
	return false
