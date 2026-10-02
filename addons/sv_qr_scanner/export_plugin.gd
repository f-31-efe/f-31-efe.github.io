@tool
extends EditorPlugin
## SvQrScanner Android eklentisi kabuğunu dışa aktarım sürecine bağlar.
## AAR dosyaları scripts/build_plugin.sh ile üretilir:
##   addons/sv_qr_scanner/bin/debug/sv_qr_scanner-debug.aar
##   addons/sv_qr_scanner/bin/release/sv_qr_scanner-release.aar

var export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name := "sv_qr_scanner"

	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_name() -> String:
		return _plugin_name

	func _get_android_libraries(platform, debug: bool) -> PackedStringArray:
		var rel := _plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar" if debug \
			else _plugin_name + "/bin/release/" + _plugin_name + "-release.aar"
		var full := "res://addons/" + rel
		if not FileAccess.file_exists(full):
			push_warning("SvQrScanner: AAR bulunamadı (" + full + "). " \
				+ "Tarama özellikleri devre dışı dışa aktarılıyor. " \
				+ "Derlemek için: sh scripts/build_plugin.sh")
			return PackedStringArray()
		return PackedStringArray([rel])

	func _get_android_dependencies(platform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			# Kamera önizleme + CameraX yaşam döngüsü
			# (1.5.3 — Godot Android şablonunun AGP 8.6.1 ile uyumlu en yeni sürüm)
			"androidx.camera:camera-camera2:1.5.3",
			"androidx.camera:camera-lifecycle:1.5.3",
			"androidx.camera:camera-view:1.5.3",
			# Barkod çözümleme (cihaz üzerinde, çevrimdışı model)
			"com.google.mlkit:barcode-scanning:17.3.0",
			# FileProvider + ComponentActivity
			"androidx.core:core:1.13.1",
			"androidx.activity:activity:1.9.3",
			# Reklamlar (AdMob)
			"com.google.android.gms:play-services-ads:25.5.0",
		])

	func _get_android_manifest_application_element_contents(platform, debug: bool) -> String:
		# AdMob uygulama kimliği. Varsayılan Google test kimliğidir;
		# production için README > "AdMob" bölümündeki kendi kimliğinizle değiştirin.
		return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" ' \
			+ 'android:value="ca-app-pub-3940256099942544~3347511713"/>'
