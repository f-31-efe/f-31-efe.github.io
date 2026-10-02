class_name HistoryScreen
extends MarginContainer
## Geçmiş sekmesi: arama, filtreler, favoriler, CSV dışa aktarma.

const FILTERS := [
	["all", "Tümü"],
	["scan", "Taramalar"],
	["gen", "Oluşturmalar"],
	["fav", "Favoriler"],
]

var app: Control
var _search: LineEdit
var _filter := "all"
var _chips: Dictionary = {}
var _list: VBoxContainer
var _count_label: Label
var _empty_box: VBoxContainer


func _init(app_ref: Control) -> void:
	app = app_ref
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()


func _build() -> void:
	var body := W.vbox([], 12)

	var head := W.vbox([], 2)
	head.add_child(W.label("Geçmiş", "H1Label", 30, true))
	_count_label = W.wrap("", "MutedLabel", 14)
	head.add_child(_count_label)
	body.add_child(head)

	# Arama
	_search = LineEdit.new()
	_search.placeholder_text = "İçerikte ara…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(0, 48)
	_search.text_changed.connect(func(_t: String) -> void:
			rebuild())
	body.add_child(_search)

	# Filtre çipleri
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for f in FILTERS:
		var c := W.chip(f[1])
		c.toggle_mode = true
		c.button_group = group
		c.set_pressed_no_signal(f[0] == _filter)
		var key: String = f[0]
		c.pressed.connect(func() -> void:
				_filter = key
				rebuild())
		flow.add_child(c)
		_chips[key] = c
	body.add_child(flow)

	# Liste
	_list = W.vbox([], 8)
	body.add_child(_list)
	_empty_box = W.vbox([], 8)
	body.add_child(_empty_box)

	# Alt eylemler
	var actions := W.hbox([], 8)
	var csv_btn := W.secondary("CSV Dışa Aktar", func() -> void:
			app.export_csv())
	csv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(csv_btn)
	var clear_btn := W.danger("Geçmişi Sil", func() -> void:
			app.confirm(
				"Geçmişi Sil",
				"Tüm tarama ve oluşturma kayıtları kalıcı olarak silinecek. Bu işlem geri alınamaz.",
				_clear_confirmed))
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(clear_btn)
	body.add_child(actions)
	body.add_child(W.gap(8))

	add_child(W.scroll(body))


func _clear_confirmed() -> void:
	Store.clear_history()
	rebuild()
	app.toast("Geçmiş temizlendi")


func rebuild() -> void:
	if _list == null:
		return
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	for ch in _empty_box.get_children():
		_empty_box.remove_child(ch)
		ch.queue_free()

	var items := Store.query(_search.text if _search else "", _filter)
	_count_label.text = "%d kayıt" % items.size()

	if items.is_empty():
		var msg := "Kayıt bulunamadı."
		if Store.history().is_empty():
			msg = "Geçmiş boş. İlk kodunuzu tarayın veya QR kod oluşturun."
		_empty_box.add_child(W.card([W.wrap(msg, "MutedLabel", 14)], 6))
		return

	var rendered := 0
	for e in items:
		if rendered >= 120:
			var more := W.label("… ve %d kayıt daha" % (items.size() - rendered), "MutedLabel", 13)
			_list.add_child(more)
			break
		_list.add_child(_row(e))
		rendered += 1


func _row(e: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "SecondaryButton"
	b.custom_minimum_size = Vector2(0, 68)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_contents = true
	var badge := "Tarama" if str(e.get("kind", "")) == "scan" else "Oluşturma"
	var title := str(e.get("title", ""))
	if bool(e.get("fav", false)):
		title += "  ·  Favori"
	b.text = "%s · %s · %s\n%s" % [badge, Payload.type_label(str(e.get("type", "text"))), title, str(e.get("content", ""))]
	b.pressed.connect(func() -> void:
			app.show_result(e))
	return b


func refresh() -> void:
	rebuild()


func on_retheme() -> void:
	pass
