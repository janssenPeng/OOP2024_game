extends HBoxContainer

@export var stats: Stats

@onready var health_bar = $V/HealthBar
@onready var eased_health_bar = $V/HealthBar/EasedHealthBar
@onready var energy_bar = $V/EnergyBar


func _ready():
	stats.health_changed.connect(update_health)
	update_health()
	
	stats.energy_changed.connect(update_energy)
	update_energy()

func update_health():
	var percentage := stats.health / float(stats.max_health)
	health_bar.value = percentage
	
	create_tween().tween_property(eased_health_bar, "value", percentage, 0.3)


func update_energy():
	var percentage := stats.energy / stats.max_energy
	energy_bar.value = percentage
