extends Enemy

enum State {
	IDLE,
	WALK,
	RUN,
	HURT,
	DYING,
}

const KNOCK_BACK_AMOUNT := 512.0

var pending_damage: Damage

@onready var wall_checker = $Graphics/WallChecker
@onready var player_checker = $Graphics/PlayerChecker
@onready var floor_checker = $Graphics/FloorChecker
@onready var calm_down_timer = $CalmDownTimer
@onready var stats: Stats = $Stats


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.HURT, State.DYING:
			move(0.0 , delta)
			
		State.WALK:
			move(max_speed / 3, delta)
			
		State.RUN:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)
			if player_checker.is_colliding():
				calm_down_timer.start()

func get_next_state(state: State) -> State:
	if stats.health == 0:
		return State.DYING
	
	if pending_damage:
		return State.HURT
	
	match state:
		State.IDLE:
			if player_checker.is_colliding():
				return State.RUN
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if player_checker.is_colliding():
				return State.RUN
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		
		State.RUN:
			if not player_checker.is_colliding() and calm_down_timer.is_stopped():
				return State.WALK
		
		State.HURT:
			if not animation_player.is_playing():
				return State.RUN
	return state

func transition_state(from: State, to: State) -> void:
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])


	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
		
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				direction *= -1
			
		State.RUN:
			animation_player.play("run")
			
		State.HURT:
			animation_player.play("hit")
			stats.health -= pending_damage.amount
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCK_BACK_AMOUNT
			
			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT
			
			pending_damage = null
			
		State.DYING:
			animation_player.play("die")


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1.5
	pending_damage.source = hitbox.owner
