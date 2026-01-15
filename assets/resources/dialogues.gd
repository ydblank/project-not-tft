extends Resource
class_name DialoguesDB

# Dialogue DB structure (example):
# dialogues = {
#   "intro": {
#     "start": "n1",
#     "nodes": {
#       "n1": {"speaker": "NPC", "text": "Hello!", "choices": [{"text": "Hi", "to": "n2"}]},
#       "n2": {"speaker": "NPC", "text": "Bye.", "choices": []}
#     }
#   }
# }
@export var dialogues = {
	"intro": {
		"start": "n1",
		"nodes": {
			"n1": {
				"speaker": "Narrator",
				"text": "Welcome. Do you want a quick tutorial?",
				"choices": [
					{"text": "Yes", "to": "n2"},
					{"text": "No", "to": "end"}
				]
			},
			"n2": {
				"speaker": "Narrator",
				"text": "WASD to move. Primary to attack. Dash to dash.",
				"choices": [
					{"text": "Got it", "to": "end"}
				]
			},
			"end": {
				"speaker": "Narrator",
				"text": "Good luck.",
				"choices": []
			}
		}
	}
}
