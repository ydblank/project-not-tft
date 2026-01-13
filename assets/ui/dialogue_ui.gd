extends CanvasLayer

@export var dialogues_db: DialoguesDB = preload("res://assets/resources/dialogues.tres")
@export var dialogue_id: String = "intro"
@export var start_node_id: String = "n1"

@onready var dialogue_box: Label = $DialogueBox

func _ready() -> void:
	if dialogues_db == null:
		dialogue_box.text = "[Dialogue] dialogues_db not set"
		return
	if not dialogues_db.dialogues.has(dialogue_id):
		dialogue_box.text = "[Dialogue] missing id: %s" % dialogue_id
		return

	var d: Dictionary = dialogues_db.dialogues[dialogue_id]
	var nodes: Dictionary = d.get("nodes", {})
	var node_id: String = start_node_id
	if d.has("start"):
		node_id = str(d["start"])

	if not nodes.has(node_id):
		dialogue_box.text = "[Dialogue] missing node: %s" % node_id
		return

	var node: Dictionary = nodes[node_id]
	dialogue_box.text = str(node.get("text", ""))
