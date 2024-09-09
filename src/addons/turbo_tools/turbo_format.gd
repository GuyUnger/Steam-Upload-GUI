@tool
class_name TurboFormat
extends Node

#TODO: use the build in is_in_comment and is_in_string instead

var SPACES_TO_TABS: bool = true
var COMPLETE_FLOATS: bool = true
var REMOVE_DOUBLE_SPACES: bool = true
var REMOVE_TRAILING_WHITE: bool = true
var KEEP_INDENTATION: bool = true

var turbo: Turbo


func format_line(line_num: int) -> bool:
	var code_editor: CodeEdit = turbo.code_editor
	var text: String = code_editor.get_line(line_num)
	var text_previous: String = code_editor.get_line(line_num - 1) if line_num > 0 else ""
	
	var text_stripped := code_editor.get_line(line_num).strip_edges()
	
	# Comments.
	if text_stripped.begins_with("#") and false:
		if text_stripped.length() > 2:
			var comment_start_column := text.find("#")
			var comment := text.substr(comment_start_column + 1)
			if comment[0] == " ":
				var before := text.substr(0, comment_start_column + 1)
				var formatted_comment := comment
				if not is_comment(line_num - 1):
					# Capitalize first letter.
					formatted_comment[1] = formatted_comment[1].to_upper()
				if not is_comment(line_num + 1):
					# Add period.
					var last_char := formatted_comment[formatted_comment.length() - 1]
					if not last_char in ".#,:!?":
						formatted_comment += "."
				if formatted_comment != comment:
					code_editor.set_line(line_num, before + formatted_comment)
					return true
		return false
	
	# Ensure 2 empty lines between functions.
	if text.begins_with("func ") or text.begins_with("static func "):
		var previous_line := line_num - 1
		# Skip comments.
		while code_editor.get_line(previous_line).begins_with("#") or code_editor.get_line(previous_line).begins_with("@warning_ignore"):
			previous_line -= 1
			if previous_line <= 0:
				break
		# Has one line of space.
		if code_editor.get_line(previous_line).strip_edges() == "":
			# Doesn't have two lines of space.
			if code_editor.get_line(previous_line - 1).strip_edges() != "":
				code_editor.insert_line_at(previous_line + 1, "")
				#if not code_editor.get_line(previous_line - 1).strip_edges(true, false).begins_with("return"):
					#code_editor.set_line(previous_line, "")
				return true
		else:
			# Doesn't have any lines of space.
			code_editor.insert_line_at(previous_line + 1, "")
			code_editor.insert_line_at(previous_line + 1, "")
			return true
	
	if text_stripped == "":
		var empty := 1
		for i in range(1, 3):
			if code_editor.get_line(line_num - i).strip_edges() == "":
				empty += 1
			else:
				break
		for i in range(1, 3):
			if code_editor.get_line(line_num + i).strip_edges() == "":
				empty += 1
			else:
				break
		if empty > 2:
			code_editor.remove_line_at(line_num)
			return true
	
	# Automatic typing
	if (
			not text_previous.contains('@warning_ignore("untyped_declaration")')
			and not text_previous.contains("@warning_ignore('untyped_declaration')")
	):
		if text.begins_with("func ") and text.ends_with("):"):
			text = text.replace("):", ") -> void:")
		
		if text_stripped.begins_with("var ") and not text.contains(":"):
			for i in text.length():
				if text[i] == "=":
					text = text.insert(i, ":")
					break
	
	const SINGLE_QUOTE = "'"
	const DOUBLE_QUOTE = '"'
	var is_path: bool = false
	var is_string: bool = false
	var string_type: String = ""
	var i := -1
	while i < text.length() - 1:
		i += 1
		
		var symbol := text[i]
		var is_last_character := i == text.length() - 1
		
		# Check is in string.
		if symbol == SINGLE_QUOTE:
			if is_string:
				if string_type == SINGLE_QUOTE:
					is_string = false
			else:
				is_string = true
				string_type = SINGLE_QUOTE
			continue
		if symbol == DOUBLE_QUOTE:
			if is_string:
				if string_type == DOUBLE_QUOTE:
					is_string = false
			else:
				is_string = true
				string_type = DOUBLE_QUOTE
			continue
		if is_string:
			continue
		
		# Comment started, quit.
		if symbol == "#":
			break
		
		# Check if in node path.
		if "$%".contains(symbol):
			is_path = true
			continue
		if is_path:
			if " .".contains(symbol):
				is_path = false
			continue
		
		# Double spaces and tabs.
		if symbol == " ":
			var count: int = 0
			var j := i
			while j < text.length() - 1:
				j += 1
				if text[j] == " ":
					count += 1
				else:
					break
			
			if count > 0:
				count += 1
				if count >= 4:
					text = text.erase(i, count)
					var tabs: int = floori(count / 4.0)
					for t in tabs:
						text = text.insert(i, "\t")
				else:
					text = text.erase(i, count - 1)
			
		elif "+-*=/<>".contains(symbol): #TODO: % operator
			# Spaces around operators.
			var valid_neighbors: String = " +-*/=<>!:%"
			
			var left := text[i - 1]
			var right := text[i + 1]
			var can_be_sign: bool = "-+".contains(symbol)
			if not " (".contains(left) and (can_be_sign or not valid_neighbors.contains(left)):
				# Add space to left.
				text = text.insert(i, " ")
				i += 1
			if is_last_character or not valid_neighbors.contains(right):
				# Add space to right.
				if can_be_sign and (valid_neighbors + ",()").contains(text[i - 2]):
					continue
				text = text.insert(i + 1, " ")
			
		elif symbol == ",":
			# Spaces around commas.
			if text[i - 1] == " ":
				text = text.erase(i - 1, 1)
				i -= 1
			if not is_last_character and text[i + 1] != " ":
				text = text.insert(i + 1, " ")
		elif symbol == ".":
			# Complete floats.
			if text[i - 1].is_valid_int():
				# Add 0 to right of period.
				if is_last_character or not text[i + 1].is_valid_int():
					var j := i
					var is_float: bool = true
					while j > 0:
						j -= 1
						if not text[j].is_valid_int():
							if not " 	-+".contains(text[j]):
								is_float = false
							break
					if is_float:
						text = text.insert(i + 1, "0")
			elif is_last_character or text[i + 1].is_valid_int():
				# Add 0 to left of period.
				if not text[i - 1].is_valid_int():
					text = text.insert(i, "0")
					i += 1
	
	if text.ends_with(";"):
		text = text.substr(0, text.length() - 1)
	
	# Removing trailing whitespace at end of line.
	if text_stripped != "":
		while text.ends_with(" ") or text.ends_with("\t"):
			text = text.substr(0, text.length() - 1)
	
	if code_editor.get_line(line_num) != text:
		code_editor.set_line(line_num, text)
		return true
	return false


func get_indentation(string: String) -> String:
	var indentation: String = ""
	for i in string:
		if i == '\t' or i == ' ':
			indentation += i
		else:
			break
	return indentation


func is_comment(line_num: int) -> bool:
	if line_num <= 0 or line_num > turbo.code_editor.get_line_count():
		return false
	return turbo.code_editor.get_line(line_num).strip_edges(true, false).begins_with("#")
