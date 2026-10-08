extends Label

@onready var player = get_tree().current_scene.get_node("Player")
var xp_bar

func _ready():
	# XP bar, placed directly under this label
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(200, 14)
	xp_bar.min_value = 0
	xp_bar.max_value = player.XP_PER_LEVEL
	get_parent().add_child.call_deferred(xp_bar)

	player.health_changed.connect(refresh)
	player.xp_changed.connect(refresh)
	refresh()

func refresh(_a = 0, _b = 0):
	text = "IGNITOR\nLvl. %d\nHP: %d / %d\nXP: %d / %d" % [player.level, player.health, player.max_health, player.xp, player.XP_PER_LEVEL]
	xp_bar.value = player.xp
