extends CharacterBody3D

#Player Node
@onready var eyes = $Neck/Head/Eyes
@onready var head = $Neck/Head
@onready var standing_collision_shape = $StandingCollisionShape
@onready var crouching_collision_shape = $CrouchingCollisionShape
@onready var ray_cast_3d = $RayCast3D
@onready var neck = $Neck
@onready var camera_3d = $Neck/Head/Eyes/Camera3D
@onready var animation_player = $Neck/Head/Eyes/AnimationPlayer

#Speed Variables
var current_speed = 5.0
const walking_speed= 5.0
const sprinting_speed=8.0
const crouching_speed=3.0

#States
var walking=false
var sprinting=false
var crouching=false
var free_looking=false
var sliding=false

#Sliding variables
var slide_timer=0.0
var slide_timer_max=1.0
var slide_vector=Vector2.ZERO
var slide_speed=10

#Head-Bobbing variables
const head_bobbing_sprinting_speed=22.0
const head_bobbing_walking_speed=14.0
const head_bobbing_crouching_speed=10.0

const head_bobbing_crouching_intensity=0.05
const head_bobbing_walking_intensity=0.1
const head_bobbing_sprinting_intensity=0.2

var head_bobbing_vector=Vector2.ZERO
var head_bobbing_index=0.0
var head_bobbing_current_intensity=0.0

#Movement Variables
const jump_velocity = 4.5
var crouching_depth = -0.5
var lerp_speed= 15
var free_look_tilt=8
var air_lerp_speed=3.0
var last_velocity=Vector2.ZERO

#Input Variables
var direction=Vector3.ZERO
const mouse_sens=0.4

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x*mouse_sens))
			neck.rotation.y=clamp(neck.rotation.y,deg_to_rad(-60),deg_to_rad(60))
		else:
			rotate_y(-deg_to_rad(event.relative.x*mouse_sens))
		head.rotate_x(-deg_to_rad(event.relative.y*mouse_sens))
		head.rotation.x=clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad(89))
		
func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	#Handling Movement States
	
	#Crouching
	if Input.is_action_pressed("crouch") || sliding:
		standing_collision_shape.disabled=true
		crouching_collision_shape.disabled=false
		
		current_speed=lerp(current_speed, crouching_speed,delta*lerp_speed)
		head.position.y=lerp(head.position.y,crouching_depth,delta*lerp_speed)
		
		#Slide Begin Logic
		if sprinting && input_dir!=Vector2.ZERO:
			sliding=true
			slide_timer=slide_timer_max
			slide_vector=input_dir
			free_looking=true
			print("slide begin")
		
		walking=false
		sprinting=false
		crouching=true
	#Standing	
	elif !ray_cast_3d.is_colliding():
		standing_collision_shape.disabled=false
		crouching_collision_shape.disabled=true
		
		head.position.y=lerp(head.position.y,0.0,delta*lerp_speed)
		#Sprinting
		if Input.is_action_pressed("sprint"):
			current_speed=lerp(current_speed, sprinting_speed,delta*lerp_speed)
			walking=false
			sprinting=true
			crouching=false
		#Walking
		else:
			walking=true
			sprinting=false
			crouching=false
			current_speed=lerp(current_speed, walking_speed,delta*lerp_speed)
	#handling free looking
	if Input.is_action_pressed("free_look") || sliding:
		free_looking=true
		#camera_3d.rotation.z=neck.rotation.y*-deg_to_rad(free_look_tilt)
		if sliding:
			eyes.rotation.z=lerp(eyes.rotation.z,-deg_to_rad(7.0),delta*lerp_speed)
		else:
			eyes.rotation.z=neck.rotation.y*-deg_to_rad(free_look_tilt)
	else:
		free_looking=false
		neck.rotation.y=lerp(neck.rotation.y,0.0,delta*lerp_speed)
		eyes.rotation.z=lerp(eyes.rotation.z,0.0,delta*lerp_speed)
		
	#Handling Sliding
	if sliding:
		slide_timer-=delta
		if slide_timer<=0:
			sliding=false
			free_looking=false
			
	
	#Handling head bobbing
	if sprinting:
		head_bobbing_current_intensity=head_bobbing_sprinting_intensity
		head_bobbing_index+=head_bobbing_sprinting_speed*delta
	elif walking:
		head_bobbing_current_intensity=head_bobbing_walking_intensity
		head_bobbing_index+=head_bobbing_walking_speed*delta
	elif crouching:
		head_bobbing_current_intensity=head_bobbing_crouching_intensity
		head_bobbing_index+=head_bobbing_crouching_speed*delta
		
	if is_on_floor() && !sliding && input_dir!=Vector2.ZERO:
		head_bobbing_vector.y=sin(head_bobbing_index)
		head_bobbing_vector.x=sin(head_bobbing_index/2)+0.5
		eyes.position.y=lerp(eyes.position.y,head_bobbing_vector.y*(head_bobbing_current_intensity/2.0),delta*lerp_speed)
		eyes.position.x=lerp(eyes.position.x,head_bobbing_vector.x*(head_bobbing_current_intensity/2.0),delta*lerp_speed)
	else:
		eyes.position.y=lerp(eyes.position.y,0.0,delta*lerp_speed)
		eyes.position.x=lerp(eyes.position.x,0.0,delta*lerp_speed)
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		sliding=false
		animation_player.play("jump")
	
	if is_on_floor():
		if last_velocity.y<-10.0:
			animation_player.play("roll")
			print(last_velocity.y)	
		elif last_velocity.y<0.0:
			animation_player.play("landing")
			print(last_velocity.y)
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*lerp_speed)
	else:
		if input_dir!=Vector2.ZERO:
			direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*air_lerp_speed)
	if sliding:
		direction=(transform.basis*Vector3(slide_vector.x,0,slide_vector.y)).normalized()
		current_speed= (slide_timer+0.1)*slide_speed
		
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
			
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	last_velocity=velocity
	move_and_slide()
	
