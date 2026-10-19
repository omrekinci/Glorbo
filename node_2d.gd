extends Node2D

var speed = 300
var direction = Vector2(1, 1).normalized()
var screen_size = Vector2()
var window_size = Vector2(200, 200)

var idle_timer = 0.0
var is_idling = false
var is_dragging = false

var drag_offset = Vector2()
var last_mouse_pos = Vector2()
var throw_velocity = Vector2()

var wander_timer = 0.0
var wander_time = 3.0

var shake_accumulator = 0.0
var last_drag_dir = Vector2.ZERO

var is_stopped = false
var is_main_grounded = false

var active_window_2: Node = null

enum State { WANDER, CHASE, ON_COW }
var current_state = State.WANDER
var current_target: Node = null

var popup_menu: PopupMenu
var spawn_timer = 0.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $Area2D

func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("default")
	
	if not area.input_event.is_connected(_on_area_input):
		area.input_event.connect(_on_area_input)
	
	popup_menu = PopupMenu.new()
	add_child(popup_menu)
	popup_menu.add_item("Summon Cow", 0)
	popup_menu.id_pressed.connect(_on_menu_item_pressed)
	wander_time = randf_range(0.5, 2.0)

func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var mouse_pos = DisplayServer.mouse_get_position()
			popup_menu.position = Vector2i(mouse_pos)
			popup_menu.popup()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			shake_accumulator = 0.0
			last_drag_dir = Vector2.ZERO
			is_main_grounded = false
			current_state = State.WANDER
			current_target = null
			if not is_stopped:
				animated_sprite.play("default")
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var win_pos = Vector2(DisplayServer.window_get_position())
			drag_offset = mouse_pos - win_pos
			last_mouse_pos = mouse_pos
			throw_velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= 1.0:
		spawn_timer = 0.0
		if randi() % 33 == 0:
			spawn_cow()

	if is_stopped:
		if is_dragging:
			is_main_grounded = false
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				is_dragging = false
			else:
				var mouse_pos = Vector2(DisplayServer.mouse_get_position())
				var new_win_pos = mouse_pos - drag_offset
				DisplayServer.window_set_position(Vector2i(new_win_pos))
				last_mouse_pos = mouse_pos
			return

		if is_instance_valid(active_window_2):
			if active_window_2.get("is_grounded"):
				var main_rect = Rect2(Vector2(DisplayServer.window_get_position()), window_size)
				var win2_rect = Rect2(Vector2(active_window_2.position), Vector2(active_window_2.size))
				
				if main_rect.intersects(win2_rect):
					active_window_2.queue_free()
					active_window_2 = null
					is_stopped = false
					is_main_grounded = false
					speed = 300
					direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
					animated_sprite.play("default")
					return

		var current_win_pos = Vector2(DisplayServer.window_get_position())
		var taskbar_y = int(screen_size.y - window_size.y - 55)
		
		if current_win_pos.y < taskbar_y:
			current_win_pos.y = move_toward(current_win_pos.y, taskbar_y, 300.0 * delta)
			DisplayServer.window_set_position(Vector2i(current_win_pos))
		else:
			is_main_grounded = true
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("emptyoff"):
				if animated_sprite.animation != "emptyoff":
					animated_sprite.play("emptyoff")
					
		return

	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging = false
		animated_sprite.play("neausea")
		current_state = State.WANDER
		current_target = null
		
		var current_mouse = Vector2(DisplayServer.mouse_get_position())
		throw_velocity = (current_mouse - last_mouse_pos) / delta
		
		if throw_velocity.length() > 50:
			direction = throw_velocity.normalized()
			speed = clamp(throw_velocity.length() * 0.5, 300, 2500)

	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var new_win_pos = mouse_pos - drag_offset
		
		var movement = mouse_pos - last_mouse_pos
		if movement.length() > 2.0:
			var current_dir = movement.normalized()
			if last_drag_dir != Vector2.ZERO:
				if current_dir.dot(last_drag_dir) < -0.2:
					shake_accumulator += movement.length()
			last_drag_dir = current_dir
			
		if shake_accumulator > 400.0:
			shake_accumulator = 0.0
			is_stopped = true
			speed = 0
			animated_sprite.rotation = deg_to_rad(0)
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("empty"):
				animated_sprite.play("empty")
			spawn_window_2()
		
		DisplayServer.window_set_position(Vector2i(new_win_pos))
		last_mouse_pos = mouse_pos
		return

	if current_state == State.WANDER:
		var falling_cows = get_tree().get_nodes_in_group("falling_cow")
		for cow in falling_cows:
			if cow.get("is_ready_for_glorbo") and not cow.get("is_cow_on_top"):
				current_target = cow
				current_state = State.CHASE
				break

	if current_state == State.CHASE:
		if not is_instance_valid(current_target) or not current_target.get("is_grounded"):
			current_state = State.WANDER
			current_target = null
			return

		animated_sprite.rotation = deg_to_rad(0)
		
		var target_pos = Vector2(current_target.position.x, current_target.position.y - window_size.y + 100)
		var current_win_pos = Vector2(DisplayServer.window_get_position())
		
		var distance = current_win_pos.distance_to(target_pos)
		if distance <= speed * delta + 5.0:
			DisplayServer.window_set_position(Vector2i(target_pos))
			current_state = State.ON_COW
			animated_sprite.play("default")
		else:
			current_win_pos = current_win_pos.move_toward(target_pos, speed * delta)
			DisplayServer.window_set_position(Vector2i(current_win_pos))
		
		if target_pos.x > current_win_pos.x:
			animated_sprite.flip_h = false
		else:
			animated_sprite.flip_h = true
		return

	if current_state == State.ON_COW:
		if is_instance_valid(current_target):
			current_target.call("start_moving_up")
			animated_sprite.rotation = deg_to_rad(0)
			animated_sprite.play("default")
			
			var taskbar_y = int(screen_size.y - window_size.y - 55)
			DisplayServer.window_set_position(Vector2i(current_target.position.x, taskbar_y))
		else:
			current_state = State.WANDER
			current_target = null
		return
	
	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 300
			animated_sprite.play("default")
		return

	if speed == 300:
		wander_timer += delta
		if wander_timer >= wander_time:
			wander_timer = 0.0
			wander_time = randf_range(0.5, 2.0)
			direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			
			if direction.x > 0:
				animated_sprite.flip_h = false
			elif direction.x < 0:
				animated_sprite.flip_h = true
				
			animated_sprite.play("default")
			maybe_idle()

	if speed > 300:
		speed = lerp(float(speed), 300.0, 3.0 * delta)
		
	if speed > 0:
		if direction.x > 0:
			animated_sprite.rotation = deg_to_rad(10)
		elif direction.x < 0:
			animated_sprite.rotation = deg_to_rad(-10)
			
	var window_position = Vector2(DisplayServer.window_get_position())
	window_position += direction * speed * delta
	
	var bounced = false
	
	if window_position.x <= 0:
		window_position.x = 0
		direction.x *= -1
		animated_sprite.flip_h = !animated_sprite.flip_h
		bounced = true
	elif window_position.x >= screen_size.x - window_size.x:
		window_position.x = screen_size.x - window_size.x
		direction.x *= -1
		animated_sprite.flip_h = !animated_sprite.flip_h
		bounced = true
		
	if window_position.y <= 0:
		window_position.y = 0
		speed = 300
		direction.y *= -1
		bounced = true
	elif window_position.y >= screen_size.y - window_size.y:
		window_position.y = screen_size.y - window_size.y
		speed = 300
		direction.y *= -1
		bounced = true

	if bounced:
		animated_sprite.play("default")
		speed *= 0.95
		maybe_idle()

	DisplayServer.window_set_position(Vector2i(window_position))

func maybe_idle():
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(0.5, 3)
		animated_sprite.rotation = deg_to_rad(0)
		animated_sprite.play("default")
		current_state = State.WANDER
		
		var r = randi() % 3
		if r == 0:
			speed = 0

func spawn_cow():
	print("spawning cow :-D")
	var cow_scene = load("res://cow.tscn")
	if cow_scene:
		var new_cow = cow_scene.instantiate()
		get_tree().root.add_child(new_cow)
		new_cow.show()

func spawn_window_2():
	if is_instance_valid(active_window_2):
		return

	var window2_scene = load("res://window2.tscn")
	if window2_scene:
		print("Window 2 summoned")
		var new_window2 = window2_scene.instantiate()
		active_window_2 = new_window2
		
		get_tree().root.add_child(new_window2)
		
		var main_pos = Vector2(DisplayServer.window_get_position())
		var window2_size = Vector2(100, 100)
		if new_window2 is Window:
			window2_size = Vector2(new_window2.size)
		
		var center_pos = main_pos + (window_size / 2.0) - (window2_size / 2.0)
		
		var window_id = new_window2.get_window_id() if new_window2 is Window else 0
		DisplayServer.window_set_position(Vector2i(center_pos), window_id)
		
		new_window2.show()
	else:
		print("Error: res://window2.tscn could not be found")

func _on_menu_item_pressed(id: int):
	match id:
		0:
			spawn_cow()
