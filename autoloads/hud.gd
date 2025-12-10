# UI_Resources.gd
extends CanvasLayer

var wood_label: Label
var stone_label: Label
var food_label: Label
var health_bar: ProgressBar
var wave_label: Label
var time_label: Label

var game_time: float = 0.0

func _ready():
	# Initialiser les références après que l'arbre soit prêt
	wood_label = $UIResources/VBoxContainer/Wood
	stone_label = $UIResources/VBoxContainer/Stone
	food_label = $UIResources/VBoxContainer/Food
	health_bar = $UIResources/HealthBar
	wave_label = $UIResources/WaveLabel
	time_label = $UIResources/TimeLabel

func _process(delta):
	game_time += delta
	update_time_display()

func update_display(wood: int, stone: int, food: int):
	if wood_label:
		wood_label.text = "Wood: %d" % wood
	if stone_label:
		stone_label.text = "Stone: %d" % stone
	if food_label:
		food_label.text = "Food: %d" % food

func update_health(current: int, maximum: int):
	if not health_bar:
		return
	
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Change la couleur selon la vie restante
	var ratio = float(current) / float(maximum)
	if ratio > 0.6:
		health_bar.modulate = Color.GREEN
	elif ratio > 0.3:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func update_wave_info(wave: int, enemies_remaining: int):
	if wave_label:
		wave_label.text = "Wave: %d | Enemies: %d" % [wave, enemies_remaining]

func update_wave_countdown(seconds: int):
	if wave_label:
		wave_label.text = "Interval: %d seconds" % seconds

func update_time_display():
	if time_label:
		var minutes = int(game_time) / 60
		var seconds = int(game_time) % 60
		time_label.text = "Temps: %02d:%02d" % [minutes, seconds]
