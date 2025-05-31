# transition_manager.gd
extends CanvasLayer

# Enum para tipos de transição
enum TransitionType {
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
	DISSOLVE,
	WIPE_HORIZONTAL,
	WIPE_VERTICAL,
	CIRCLE_EXPAND,
	CIRCLE_CONTRACT
}

# Sinais
signal transition_started(transition_type: TransitionType)
signal transition_middle()  # Momento ideal para trocar cenas/conteúdo
signal transition_finished(transition_type: TransitionType)

# Nós da interface
@onready var transition_overlay: ColorRect
@onready var transition_material: ShaderMaterial

# Cache de shaders
var shader_cache = {}

# Estado da transição
var is_transitioning = false
var current_transition_type: TransitionType
var transition_duration = 1.0
var viewport_texture: ViewportTexture

func _ready():
	# Criar overlay de transição
	call_deferred("_setup_transition_overlay")
	
	# Carregar shaders disponíveis
	_load_shaders()
	
	print("TransitionManager inicializado")

func _setup_transition_overlay():
	# Criar ColorRect que cobrirá toda a tela
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.color = Color.TRANSPARENT
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Adicionar à árvore
	add_child(transition_overlay)

func _setup_shader_material(transition_type: TransitionType):
	if not shader_cache.has(transition_type):
		print("Shader não encontrado para tipo: ", transition_type)
		return
	
	# Criar material com shader
	transition_material = ShaderMaterial.new()
	transition_material.shader = shader_cache[transition_type]
	
	# Capturar a textura da viewport atual
	var viewport_texture = get_viewport().get_texture()
	
	# Configurar parâmetros comuns
	transition_material.set_shader_parameter("screen_texture", viewport_texture)
	transition_material.set_shader_parameter("progress", 0.0)
	
	# Configurações específicas por tipo
	match transition_type:
		TransitionType.DISSOLVE:
			transition_material.set_shader_parameter("noise_scale", 10.0)
			transition_material.set_shader_parameter("dissolve_color", Color.BLACK)
		
		TransitionType.SLIDE_LEFT:
			transition_material.set_shader_parameter("direction", Vector2(-1.0, 0.0))
			transition_material.set_shader_parameter("slide_color", Color.BLACK)
		
		TransitionType.SLIDE_RIGHT:
			transition_material.set_shader_parameter("direction", Vector2(1.0, 0.0))
			transition_material.set_shader_parameter("slide_color", Color.BLACK)
		
		TransitionType.FADE:
			transition_material.set_shader_parameter("fade_color", Color.BLACK)
			transition_material.set_shader_parameter("smoothness", 0.1)
	
	# Aplicar material ao overlay
	transition_overlay.material = transition_material

func _load_shaders():
	# Carregar shaders de transição
	shader_cache[TransitionType.FADE] = preload("uid://cuk64f61wwn38")
	shader_cache[TransitionType.SLIDE_LEFT] = preload("uid://dk0tyct2l6ury")
	shader_cache[TransitionType.SLIDE_RIGHT] = preload("uid://dk0tyct2l6ury")
	shader_cache[TransitionType.DISSOLVE] = preload("uid://dwd47crm6ry34")
	
	print("Shaders de transição carregados")

# ========== MÉTODOS PÚBLICOS ==========

func transition_between_scenes(from_scene: String, to_scene: String, transition_type: TransitionType = TransitionType.FADE, duration: float = 1.0):
	"""Faz transição entre duas cenas"""
	if is_transitioning:
		print("TransitionManager: Já existe uma transição em andamento")
		return
	
	print("Iniciando transição de cena: ", from_scene, " -> ", to_scene)
	
	is_transitioning = true
	current_transition_type = transition_type
	transition_duration = duration
	
	# Emitir sinal de início
	transition_started.emit(transition_type)
	
	# 1. Transição de saída (para preto)
	await _execute_transition_out(transition_type, duration / 2.0)
	
	# 2. Trocar a cena (com tela preta)
	transition_middle.emit()
	var error = get_tree().change_scene_to_file(to_scene)
	if error != OK:
		push_error("Erro ao carregar cena: " + str(error))
		_reset_transition_state()
		return
	
	# Aguardar um frame para garantir que a nova cena foi carregada
	await get_tree().process_frame
	
	# 3. Transição de entrada (do preto)
	await _execute_transition_in(transition_type, duration / 2.0)
	
	# Finalizar transição
	_reset_transition_state()
	transition_finished.emit(transition_type)

func _execute_transition_out(transition_type: TransitionType, duration: float):
	"""Executa a primeira parte da transição (sair da cena atual para preto)"""
	_setup_shader_material(transition_type)
	transition_overlay.visible = true
	
	# Configurar shader para transição de saída
	match transition_type:
		TransitionType.FADE:
			pass #transition_material.set_shader_parameter("transition_phase", 0) # 0 = fade out
		TransitionType.SLIDE_LEFT:
			transition_material.set_shader_parameter("direction", Vector2(-1.0, 0.0))
		TransitionType.SLIDE_RIGHT:
			transition_material.set_shader_parameter("direction", Vector2(1.0, 0.0))
	
	var tween = create_tween()
	tween.tween_method(_update_transition_progress, 0.0, 1.0, duration)
	await tween.finished

func _execute_transition_in(transition_type: TransitionType, duration: float):
	"""Executa a segunda parte da transição (do preto para nova cena)"""
	# Configurar shader para transição de entrada
	match transition_type:
		TransitionType.FADE:
			pass #transition_material.set_shader_parameter("transition_phase", 0) # 1 = fade in
		# Para slides, a direção já está configurada
	
	var tween = create_tween()
	tween.tween_method(_update_transition_progress, 1.0, 0.0, duration) #Ocorre ao contrário
	await tween.finished

func _update_transition_progress(progress: float):
	"""Atualiza o progresso da transição para todos os shaders"""
	if transition_material:
		transition_material.set_shader_parameter("progress", progress)

func transition_between_chapters(from_chapter: Resource, to_chapter: Resource, transition_type: TransitionType = TransitionType.DISSOLVE, duration: float = 1.5):
	"""Faz transição entre capítulos (sem trocar de cena)"""
	if is_transitioning:
		print("TransitionManager: Já existe uma transição em andamento")
		return
	
	print("Iniciando transição de capítulo: ", from_chapter.chapter_name if from_chapter else "None", " -> ", to_chapter.chapter_name)
	
	is_transitioning = true
	current_transition_type = transition_type
	transition_duration = duration
	
	# Emitir sinal de início
	transition_started.emit(transition_type)
	
	# Executar transição completa para capítulos
	await _execute_chapter_transition(transition_type, duration)
	
	# Finalizar transição
	_reset_transition_state()
	transition_finished.emit(transition_type)

func quick_fade(duration: float = 0.5, fade_color: Color = Color.BLACK):
	"""Fade rápido para momentos específicos"""
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_overlay.color = fade_color
	transition_overlay.visible = true
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, duration / 2.0)
	await tween.finished
	
	# Emitir sinal do meio
	transition_middle.emit()
	
	# Fade out
	tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 0.0, duration / 2.0)
	await tween.finished
	
	transition_overlay.visible = false
	transition_overlay.modulate.a = 1.0
	is_transitioning = false

# ========== MÉTODOS PRIVADOS ==========
func _execute_chapter_transition(transition_type: TransitionType, duration: float):
	"""Executa transição completa para mudança de capítulo"""
	_setup_shader_material(transition_type)
	transition_overlay.visible = true
	
	var tween = create_tween()
	
	# Primeira metade: escurecer
	match transition_type:
		TransitionType.DISSOLVE:
			tween.tween_method(_update_dissolve_progress, 0.0, 1.0, duration / 2.0)
		TransitionType.FADE:
			tween.tween_method(_update_fade_progress, 0.0, 1.0, duration / 2.0)
		_:
			tween.tween_property(transition_overlay, "modulate:a", 1.0, duration / 2.0)
	
	await tween.finished
	
	# Momento ideal para mudanças
	transition_middle.emit()
	
	# Aguardar um pouco no meio da transição
	await get_tree().create_timer(0.3).timeout
	
	# Segunda metade: clarear
	tween = create_tween()
	match transition_type:
		TransitionType.DISSOLVE:
			tween.tween_method(_update_dissolve_progress, 1.0, 0.0, duration / 2.0)
		TransitionType.FADE:
			tween.tween_method(_update_fade_progress, 1.0, 0.0, duration / 2.0)
		_:
			tween.tween_property(transition_overlay, "modulate:a", 0.0, duration / 2.0)
	
	await tween.finished

# ========== MÉTODOS DE ATUALIZAÇÃO DOS SHADERS ==========

func _update_fade_progress(progress: float):
	if transition_material:
		transition_material.set_shader_parameter("progress", progress)

func _update_slide_progress(progress: float):
	if transition_material:
		transition_material.set_shader_parameter("progress", progress)

func _update_dissolve_progress(progress: float):
	if transition_material:
		transition_material.set_shader_parameter("progress", progress)

func _reset_transition_state():
	"""Reseta o estado da transição"""
	is_transitioning = false
	transition_overlay.visible = false
	transition_overlay.material = null
	transition_overlay.modulate = Color.WHITE
	current_transition_type = TransitionType.FADE

# ========== MÉTODOS UTILITÁRIOS ==========

func is_transition_active() -> bool:
	"""Verifica se há uma transição ativa"""
	return is_transitioning

func get_available_transitions() -> Array:
	"""Retorna lista de transições disponíveis"""
	return [
		"Fade",
		"Slide Left", 
		"Slide Right",
		"Dissolve",
		"Wipe Horizontal",
		"Wipe Vertical",
		"Circle Expand",
		"Circle Contract"
	]

func transition_type_from_string(type_name: String) -> TransitionType:
	"""Converte string para TransitionType"""
	match type_name.to_lower():
		"fade":
			return TransitionType.FADE
		"slide_left", "slide left":
			return TransitionType.SLIDE_LEFT
		"slide_right", "slide right":
			return TransitionType.SLIDE_RIGHT
		"dissolve":
			return TransitionType.DISSOLVE
		"wipe_horizontal", "wipe horizontal":
			return TransitionType.WIPE_HORIZONTAL
		"wipe_vertical", "wipe vertical":
			return TransitionType.WIPE_VERTICAL
		"circle_expand", "circle expand":
			return TransitionType.CIRCLE_EXPAND
		"circle_contract", "circle contract":
			return TransitionType.CIRCLE_CONTRACT
		_:
			return TransitionType.FADE

# ========== CLEANUP ==========
func _exit_tree():
	if transition_overlay and is_instance_valid(transition_overlay):
		transition_overlay.queue_free()
