class_name StateMachine
extends Node

const KEEP_CURRENT := -1

var current_state: int = -1: 
	set(v):
		owner.transition_state(current_state, v)
		current_state = v
		state_time = 0

var state_time: float


func _ready():
	await owner.ready
	current_state = 0


func _physics_process(delta):
	while true:
		var next := owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next
	
	owner.tick_physics(current_state, delta)
	state_time += delta
