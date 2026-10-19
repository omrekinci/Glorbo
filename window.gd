extends Window

var screen_size = Vector2()
var gravity = 1250.0
var is_grounded = false
var taskbar_offset = 55

var is_dragging = false

var drag_offset = Vector2()
var last_mouse_pos = Vector2()
var velocity = Vector2()

var grounded_timer = 0.0
var target_wait_time = 0.0
var is_ready_for_glorbo = false  

var is_cow_on_top = false
var is_moving_up = false
var upward_speed = 10.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var label = $Label

func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	
	var spawn_x = randi_range(0, int(screen_size.x - size.x))
	position = Vector2i(spawn_x, 0)
	
	animated_sprite.stop()
	add_to_group("falling_cow")
	target_wait_time = randf_range(3.0, 10.0)

func start_moving_up():
	is_cow_on_top = true
	is_moving_up = true
	animated_sprite.stop()

func _input(event: InputEvent) -> void:
	if is_cow_on_top:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var window_rect = Rect2i(position, size)
		
		if event.pressed:
			if event.double_click:
				print("Moo")
				is_dragging = false
				label.show()
				await get_tree().create_timer(1.5).timeout
				label.hide()
				return
			
			if window_rect.has_point(mouse_pos):
				is_dragging = true
				drag_offset = mouse_pos - Vector2(position)
				last_mouse_pos = mouse_pos
				velocity = Vector2.ZERO
				animated_sprite.stop()
				is_grounded = false
				grounded_timer = 0.0
				is_ready_for_glorbo = false
				is_cow_on_top = false
				is_moving_up = false
		else:
			if is_dragging:
				is_dragging = false
				var current_mouse = mouse_pos
				velocity = (current_mouse - last_mouse_pos) / get_process_delta_time()
				velocity = velocity.clamp(Vector2(-3000, -3000), Vector2(3000, 3000))

func _physics_process(delta: float) -> void:
	if is_moving_up:
		position = Vector2i(position.x, position.y - int(upward_speed * delta))
		
		var cow_rect = Rect2(Vector2(position), size)
		var node2_pos = Vector2(DisplayServer.window_get_position())
		var node2_size = Vector2(200, 200)
		var node2_rect = Rect2(node2_pos, node2_size)
		
		if cow_rect.intersects(node2_rect) or position.y <= 0:
			queue_free()
		return

	var mouse_pos = Vector2(DisplayServer.mouse_get_position())
	
	if is_dragging:
		position = Vector2i(mouse_pos - drag_offset)
		last_mouse_pos = mouse_pos
		return  

	if not is_grounded:
		velocity.y += gravity * delta
		velocity.x = lerp(velocity.x, 0.0, 3.0 * delta)
		
		var new_pos = Vector2(position) + velocity * delta
		
		if new_pos.x <= 0:
			new_pos.x = 0
			velocity.x *= -0.2
		elif new_pos.x >= screen_size.x - size.x:
			new_pos.x = screen_size.x - size.x
			velocity.x *= -0.2
			
		if new_pos.y <= 0:
			new_pos.y = 0
			velocity.y *= -0.2
			
		var ground_y = int(screen_size.y - size.y - taskbar_offset)
		if new_pos.y >= ground_y:
			new_pos.y = ground_y
			
			if abs(velocity.y) < 300:
				is_grounded = true
				velocity = Vector2.ZERO
				animated_sprite.play("default")
			else:
				velocity.y *= -0.15
				velocity.x *= 0.5
			
		position = Vector2i(new_pos)
	else:
		grounded_timer += delta
		if grounded_timer >= target_wait_time:
			is_ready_for_glorbo = true
