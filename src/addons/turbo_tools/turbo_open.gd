@tool
extends Node

var file_entries: Array = []

enum {PATH, TERMS, BUTTON, DISTANCE}

enum {MODE_SCRIPTS, MODE_SCENES}
var mode: int = 0



func load_scripts():
	clear()
	index_folder("res://", "gd")
	load_script_icons()
	mode = MODE_SCRIPTS
	%SearchLabel.text = "Search Script:"
	await get_tree().process_frame
	%SearchQuery.grab_focus()


func load_scenes():
	clear()
	index_folder("res://", "tscn")
	load_scene_icons()
	mode = MODE_SCENES
	%SearchLabel.text = "Search Scene:"
	await get_tree().process_frame
	%SearchQuery.grab_focus()


func load_script_icons():
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: int = 0
	var theme = EditorInterface.get_editor_theme()
	for entry in file_entries:
		var script = load(entry[PATH])
		var script_class = script.get_instance_base_type()
		if not theme.has_icon(script_class, "EditorIcons"):
			script_class = "Script"
		entry[BUTTON].icon = theme.get_icon(script_class, "EditorIcons")
		loaded += 1
		if loaded % 10 == 0:
			await get_tree().process_frame


func load_scene_icons():
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: int = 0
	var theme = EditorInterface.get_editor_theme()
	for entry in file_entries:
		var scene = load(entry[PATH]).instantiate()
		
		var scene_class = scene.get_class()
		
		if not theme.has_icon(scene_class, "EditorIcons"):
			scene_class = "Scene"
		entry[BUTTON].icon = theme.get_icon(scene_class, "EditorIcons")
		scene.queue_free()
		await get_tree().process_frame

func clear():
	file_entries = []
	for child in %Files.get_children():
		child.queue_free()


func index_folder(path: String, type: String):
	var dir_path = path
	var dir_access = DirAccess.open(path)
	if path == "res://":
		path = "res:/"
	for dir in dir_access.get_directories():
		#if dir == "addons":
			#continue
		if dir.begins_with("."):
			continue
		var subdir_path: String
		subdir_path = "%s/%s" % [path, dir]
		index_folder(subdir_path, type)
	
	for file_name: String in dir_access.get_files():
		if file_name.get_extension() == type:
			var file_path: String = "%s/%s" % [path, file_name]
			
			var button := Button.new()
			button.text = file_path
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_ALL
			%Files.add_child(button)
			
			var terms := file_name.substr(0, file_name.length() - type.length() -1).split("_")
			
			var file_entry = [file_path, terms, button, 0.0]
			file_entries.push_back(file_entry)
			
			button.pressed.connect(on_button_pressed.bind(file_entry))


func on_button_pressed(entry: Array):
	var path: String = entry[PATH]
	if path.get_extension() == "gd":
		EditorInterface.edit_script(load(entry[PATH]))
	else:
		EditorInterface.open_scene_from_path(entry[PATH])
	close()


func _on_line_edit_text_changed(new_text: String) -> void:
	search()


func search():
	var query = %SearchQuery.text
	
	for entry in file_entries:
		entry[DISTANCE] = similarity(query, entry[TERMS])
	
	file_entries.sort_custom(sort_entries)
	
	for entry in file_entries:
		%Files.move_child(entry[BUTTON], file_entries.size())
	
	%SearchQuery.grab_focus()


func similarity(query: String, terms: Array):
	var query_split_spaces = query.split(" ")
	var query_terms: Array = []
	for v in query_split_spaces:
		query_terms.append_array(v.split("_"))
	
	var value: float = - abs(terms.size() - query_terms.size()) * 0.2
	
	for query_term in query_terms:
		var query_value = 0.0
		for target_term in terms:
			query_value = max(query_value, query_term.similarity(target_term))
		value += query_value
	return value


func sort_entries(a, b):
	return a[DISTANCE] > b[DISTANCE]


func _input(event):
	if event is InputEventKey and event.is_pressed():
		match event.keycode:
			KEY_ENTER:
				on_button_pressed(file_entries[0])
			KEY_ESCAPE:
				close()
			KEY_TAB:
				if mode == MODE_SCRIPTS:
					load_scenes()
					if %SearchQuery.text != "":
						search()
				else:
					load_scripts()
					if %SearchQuery.text != "":
						search()


func close():
	get_parent().queue_free()
