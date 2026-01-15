extends CanvasLayer

@export var db: DialoguesDB
@onready var dialogue_box: RichTextLabel = $RichTextLabel

var current_node: Dictionary
var current_dialogue: Dictionary

func start(dialogue_id: String):
	current_dialogue = db.dialogues.get(dialogue_id, {})
	if current_dialogue.is_empty():
		return
	show_node(current_dialogue["start"])

func show_node(node_id: String):
	current_node = current_dialogue["nodes"].get(node_id, {})
	if current_node.is_empty():
		return

	# Display text with formatting
	dialogue_box.clear()
	dialogue_box.append_bbcode("[color=yellow]" + current_node["speaker"] + ":[/color] " + current_node["text"])

	# Handle choices
	if current_node["choices"].size() > 0:
		for choice in current_node["choices"]:
			# For now, just print choices to console
			print("Choice:", choice["text"], "->", choice["to"])
	else:
		print("Dialogue ended.")
