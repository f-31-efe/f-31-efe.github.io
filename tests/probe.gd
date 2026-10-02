extends SceneTree
## Headless API keşif betiği: `godot --headless -s tests/probe.gd`

func _initialize() -> void:
	var classes := ["DisplayServer", "Input", "OS", "ThemeDB"]
	var methods := [
		"is_dark_mode", "is_dark_mode_supported", "screen_get_dark_mode",
		"vibrate_handheld", "has_method",
	]
	for c in classes:
		for m in methods:
			if ClassDB.class_has_method(c, m):
				print("OK   ", c, ".", m)
	print("---- property kontrolü")
	var fv := FontVariation.new()
	print("FontVariation.variation_embolden ok: ", "variation_embolden" in fv)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	print("Image.create ok: ", img != null)
	var te := TextEdit.new()
	print("TextEdit.LINE_WRAPPING_BOUNDARY: ", TextEdit.LINE_WRAPPING_BOUNDARY)
	var tr := TextureRect.new()
	print("TextureRect.EXPAND_IGNORE_SIZE: ", TextureRect.EXPAND_IGNORE_SIZE)
	print("String join test: ", "|".join(PackedStringArray(["a", "b"])))
	print("ThemeDB.fallback_font: ", ThemeDB.fallback_font != null)
	quit(0)
