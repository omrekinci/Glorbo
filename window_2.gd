extends Window

var screen_size = Vector2()
var gravity = 2500.0
var is_grounded = false
var taskbar_offset = 50

var is_dragging = false
var drag_offset = Vector2()
var last_mouse_pos = Vector2()
var velocity = Vector2()
var is_sitting_transitioning = false

var is_walking = false
var walk_speed = 150.0
var walk_direction = 1 

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("falling"):
		animated_sprite.play("falling")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var window_rect = Rect2i(position, size)
		
		if event.pressed:
			if window_rect.has_point(mouse_pos):
				is_dragging = true
				drag_offset = mouse_pos - Vector2(position)
				last_mouse_pos = mouse_pos
				velocity = Vector2.ZERO
				is_grounded = false
				is_walking = false
				is_sitting_transitioning = false
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("falling"):
					animated_sprite.play("falling")
		else:
			if is_dragging:
				is_dragging = false
				var current_mouse = mouse_pos
				velocity = (current_mouse - last_mouse_pos) / get_process_delta_time()
				velocity = velocity.clamp(Vector2(-3000, -3000), Vector2(3000, 3000))
				is_walking = false
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("falling"):
					animated_sprite.play("falling")

func _physics_process(delta: float) -> void:
	var mouse_pos = Vector2(DisplayServer.mouse_get_position())
	
	if is_dragging:
		var new_pos = mouse_pos - drag_offset
		position = Vector2i(new_pos)
		last_mouse_pos = mouse_pos
		return  

	if is_grounded and is_walking:
		var new_x = position.x + walk_speed * walk_direction * delta
		
		if new_x <= 0:
			new_x = 0
			walk_direction = 1
			animated_sprite.flip_h = false
		elif new_x >= screen_size.x - size.x:
			new_x = screen_size.x - size.x
			walk_direction = -1
			animated_sprite.flip_h = true
			
		position = Vector2i(int(new_x), int(position.y))
		return

	if not is_grounded:
		is_walking = false
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("falling"):
			if animated_sprite.animation != "falling":
				animated_sprite.play("falling")

		velocity.y += gravity * delta
		velocity.x = lerp(velocity.x, 0.0, 2.0 * delta)
		
		var new_pos = Vector2(position) + velocity * delta
		
		if new_pos.x <= 0:
			new_pos.x = 0
			velocity.x *= -0.3
		elif new_pos.x >= screen_size.x - size.x:
			new_pos.x = screen_size.x - size.x
			velocity.x *= -0.3
			
		if new_pos.y <= 0:
			new_pos.y = 0
			velocity.y *= -0.3
			
		var ground_y = int(screen_size.y - size.y - taskbar_offset)
		if new_pos.y >= ground_y:
			new_pos.y = ground_y
			
			if abs(velocity.y) < 300:
				is_grounded = true
				velocity = Vector2.ZERO
				
				if not is_sitting_transitioning:
					is_sitting_transitioning = true
					if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("sitting"):
						animated_sprite.play("sitting")
					
					await get_tree().create_timer(2.0).timeout
					
					if is_grounded and not is_dragging:
						is_walking = true
						if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walking"):
							animated_sprite.play("walking")
					is_sitting_transitioning = false
			else:
				velocity.y *= -0.15
				velocity.x *= 0.5
			
		position = Vector2i(new_pos)
