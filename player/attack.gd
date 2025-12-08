extends State

var attack_range := 10.0
var attack_damage := 1

func enter():
	player = get_player()

	if player.animation_player:
		player.animation_player.play("attack")

	perform_attack()
	state_machine.change_state("Idle")


func perform_attack():
	var space_state = player.get_world_2d().direct_space_state

	# --- Direction vers la souris ---
	var mouse_pos = player.get_global_mouse_position()
	var direction = (mouse_pos - player.global_position).normalized()

	# --- Point d’impact centré devant le joueur ---
	var attack_center = player.global_position + direction * (attack_range * 0.6)

	# --- Setup de la zone circulaire ---
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = Transform2D(0, attack_center)
	query.collide_with_bodies = true
	visualize_hitbox(attack_center)
	var results = space_state.intersect_shape(query, 10)

	for result in results:
		var body = result.collider
		if body is ResourceNode:
			body.take_damage(attack_damage)
			break


func physics_process(delta):
	pass
	
func visualize_hitbox(center: Vector2):
	# Crée un node temporaire pour dessiner
	var debug_node = Node2D.new()
	player.get_parent().add_child(debug_node)
	debug_node.global_position = center
	
	# Timer pour effacer après 0.3s
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	timer.timeout.connect(func(): debug_node.queue_free())
	debug_node.add_child(timer)
	timer.start()
	
	# Dessine le cercle
	debug_node.queue_redraw()
	debug_node.draw.connect(func():
		debug_node.draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.3))
		debug_node.draw_arc(Vector2.ZERO, attack_range, 0, TAU, 32, Color.RED, 2))
