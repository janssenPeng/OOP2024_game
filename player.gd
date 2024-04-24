class_name Player
extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	HURT,
	DYING,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
}

const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK1, State.ATTACK2, State.ATTACK3,
]
const RUN_SPEED := 160.0
const AIR_ACCELERATION := RUN_SPEED / 0.1
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const JUMP_VELOCITY := -400.0
const WALL_JUMP_VELOCITY := Vector2(450, -300)
const KNOCKBACK_AMOUNT := 512.0
const SLIDING_ENERGY := 4.0

@export var can_combo := false

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false
var pending_damage: Damage
var interacting_with: Interactable

@onready var graphics = $Graphics
@onready var animation_player = $AnimationPlayer
@onready var coyote_timer = $CoyoteTimer
@onready var jump_request_timer = $JumpRequestTimer
@onready var hand_checker = $Graphics/HandChecker
@onready var foot_checker = $Graphics/FootChecker
@onready var state_machine = $StateMachine
@onready var stats = $Stats
@onready var invincible_timer = $InvincibleTimer
@onready var interaction_icon = $InteractionIcon
@onready var attack = $Attack
@onready var Slide = $Slide


func _unhandled_input(event):
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.interact()



func tick_physics(state: State, delta):
	interaction_icon.visible = interacting_with != null
	
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
			
		State.RUNNING:
			move(default_gravity, delta)
			
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
			
		State.FALL:
			move(default_gravity, delta)
	
		State.LANDING:
			stand(default_gravity,delta)
	
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			graphics.scale.x = get_wall_normal().x
		
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity,delta)
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)
		
		State.ATTACK1, State.ATTACK2, State.ATTACK3:
			stand(default_gravity,delta)
		
		State.HURT, State.DYING:
			stand(default_gravity,delta)
		
		State.SLIDING_END:
			stand(default_gravity,delta)
		
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
	is_first_tick = false



func move(gravity, delta):
	var direction := Input.get_axis("move_left","move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta

	if not is_zero_approx(direction):
		graphics.scale.x = 1 if direction < 0 else -1
	move_and_slide()



func stand(gravity, delta):
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	move_and_slide()



func slide(delta):
	velocity.x = graphics.scale.x * 200 * -1
	velocity.y = default_gravity * delta
	move_and_slide()



func die():
	get_tree().reload_current_scene()


func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()


func should_slide() -> bool:
	if not Input.is_action_just_pressed("slide"):
		return false
	if stats.energy < SLIDING_ENERGY:
		return false
	return not foot_checker.is_colliding()


func get_next_state(state:State) -> int:
	if stats.health == 0:
		return State.DYING
		
	if pending_damage:
		return State.HURT 
	
	var can_jump = is_on_floor() or coyote_timer.time_left > 0
	var should_jump = can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if should_slide():
				return State.SLIDING_START
			if not is_still:
				return State.RUNNING
			
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if should_slide():
				return State.SLIDING_START
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.ATTACK1:
			if not animation_player.is_playing():
				return State.ATTACK2 if is_combo_requested else State.IDLE
		
		State.ATTACK2:
			if not animation_player.is_playing():
				return State.ATTACK3 if is_combo_requested else State.IDLE
		
		State.ATTACK3:
			if not animation_player.is_playing():
				return State.IDLE
				
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_LOOP:
			if state_machine.state_time > 0.3 or is_on_wall():
				return State.SLIDING_END
	return state



func transition_state(from: State, to:State):
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	match to:
		State.IDLE:
			animation_player.play("idle")
	
		State.RUNNING:
			animation_player.play("running")
	
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
	
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
	
		State.LANDING:
			animation_player.play("landing")
	
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
	
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
	
		State.ATTACK1:
			animation_player.play("attack_1")
			is_combo_requested = false
			attack.play()
		
		State.ATTACK2:
			animation_player.play("attack_2")
			is_combo_requested = false
		
		State.ATTACK3:
			animation_player.play("attack_3")
			is_combo_requested = false
		
		State.HURT:
			animation_player.play("hurt")
			stats.health -= pending_damage.amount
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			pending_damage = null
			invincible_timer.start()
		
		State.DYING:
			animation_player.play("die")
			invincible_timer.stop()
		
		State.SLIDING_START:
			animation_player.play("sliding_start")
			stats.energy -= SLIDING_ENERGY
			Slide.play()
		
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		
		State.SLIDING_END:
			animation_player.play("sliding_end")
		
	is_first_tick = true


func _on_hurtbox_hurt(hitbox):
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
