extends Node

# kosneu-ArenaBorders: окружение арены в первой локации и в Бездне вместо чёрной пустоты (просьба
# пользователя 13.11: "как в джунглях, чтобы было видно, что мы где-то находимся").
# Вокруг арены мод ставит свои спрайты (листы ChatGPT, режет _claude/scripts/make_borders.py, папка
# borders/<тема>/big_N.png и low_N.png) в три слоя: низкие у края, высокие за ними, дальний тёмный слой.
# Расстановка своя (_place_props): предметы не заходят на арену и не пересекаются с персонажем.
# И продолжает землю за край арены: затемнённые тайлы того же фона под зубчатым контуром (outer_ground).
# Всё только рисуется: столкновений нет, на игру не влияет. Спрайты темы грузятся при первом забеге
# на её фоне.

const MOD_ID = "kosneu-ArenaBorders"
const LOG_NAME = "kosneu-ArenaBorders"
const DIR = "res://mods-unpacked/kosneu-ArenaBorders/"

# Фон игры (BackgroundData.name) -> тема. tint: общий оттенок предметов (ближние), far: дальнее кольцо,
# ground: затемнение земли за краем, sway: покачивание (растения, вода).
const THEMES = {
	"BG_DIRT": {"dir": "dirt", "tint": Color(0.67, 0.62, 0.57), "far": Color(0.41, 0.36, 0.32), "ground": Color(0.5, 0.46, 0.44), "sway": 0.0},
	"BG_FOREST": {"dir": "forest", "tint": Color(0.57, 0.65, 0.65), "far": Color(0.32, 0.41, 0.41), "ground": Color(0.48, 0.52, 0.54), "sway": 1.0},
	"BG_VOLCANO": {"dir": "volcano", "tint": Color(0.69, 0.65, 0.64), "far": Color(0.41, 0.38, 0.38), "ground": Color(0.46, 0.44, 0.44), "sway": 0.0},
	"BG_DREAMY_LANDS": {"dir": "dreamy", "tint": Color(0.69, 0.62, 0.65), "far": Color(0.45, 0.36, 0.41), "ground": Color(0.52, 0.46, 0.5), "sway": 0.0},
	"BG_BONEYARD": {"dir": "boneyard", "tint": Color(0.65, 0.60, 0.53), "far": Color(0.40, 0.35, 0.30), "ground": Color(0.5, 0.46, 0.42), "sway": 0.0},
	"BG_DARKLANDS": {"dir": "darklands", "tint": Color(0.62, 0.64, 0.69), "far": Color(0.36, 0.38, 0.43), "ground": Color(0.46, 0.46, 0.5), "sway": 0.0},
	"BG_OCEAN": {"dir": "ocean", "tint": Color(0.55, 0.65, 0.72), "far": Color(0.31, 0.40, 0.49), "ground": Color(0.46, 0.52, 0.58), "sway": 1.0},
	"BG_SHIPWRECK": {"dir": "wreck", "tint": Color(0.62, 0.62, 0.60), "far": Color(0.36, 0.37, 0.38), "ground": Color(0.48, 0.48, 0.48), "sway": 0.0},
	"BG_ABYSS": {"dir": "shells", "tint": Color(0.62, 0.60, 0.72), "far": Color(0.36, 0.34, 0.47), "ground": Color(0.46, 0.45, 0.54), "sway": 0.0},
}

# Выключатель для съёмки сравнений "было / стало": выставляется снаружи (тестовый драйвер, expr) до старта забега.
var enabled: = true

const OuterGround = preload("res://mods-unpacked/kosneu-ArenaBorders/outer_ground.gd")


func _init() -> void:
	ModLoaderLog.info("Initialized", LOG_NAME)


func _ready() -> void:
	var ru = Translation.new()
	ru.locale = "ru"
	ru.add_message("kosneu-ArenaBorders", "Окружение арены")
	TranslationServer.add_translation(ru)
	var _error = get_tree().connect("node_added", self, "_on_node_added")


# Землю и предметы ставим, когда сцена волны готова (тайлы арены расставлены, зона известна).
func _on_node_added(node: Node) -> void:
	if not enabled or node.get_parent() != get_tree().root or node.filename != "res://main.tscn":
		return
	var background = RunData.get_background()
	if background == null:
		return
	var theme = THEMES.get(String(background.name))
	if theme == null:
		return
	var _error = node.connect("ready", self, "_on_main_ready", [node, background, theme], CONNECT_ONESHOT)


func _on_main_ready(main: Node, background, theme: Dictionary) -> void:
	var tile_map = main.get("_tile_map")
	if tile_map == null or tile_map.has_node("CodexOuterGround"):
		return
	var ground = OuterGround.new()
	ground.name = "CodexOuterGround"
	ground.add_to_group("codex_arena_border")
	ground.setup(tile_map, background.get_tiles_sprite(), theme.ground)
	tile_map.add_child(ground)
	tile_map.move_child(ground, 0)
	var container = main.get("_entities_container")
	if container != null:
		_place_props(container, theme)


var _texture_cache = {}  # тема -> {"big": [...], "low": [...]}


func _textures(theme_dir: String, prefix: String) -> Array:
	var key = theme_dir + "/" + prefix
	if _texture_cache.has(key):
		return _texture_cache[key]
	var result = []
	for i in 12:
		var path = DIR + "borders/" + theme_dir + "/" + prefix + "_" + str(i) + ".png"
		# сначала проверка: Image.load отсутствующего файла пишет ERROR с путём мода в журнал движка,
		# а Brotato при следующем запуске считает это падением мода и отключает все моды (1.1.3)
		if not File.new().file_exists(path):
			break
		var image = Image.new()
		if image.load(path) != OK:
			break
		var tex = ImageTexture.new()
		tex.create_from_image(image, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
		result.push_back(tex)
	_texture_cache[key] = result
	return result


# Покачивание как у деревьев джунглей (шейдер игры), сила по теме.
static func _sway_material(amount: float) -> Material:
	if amount <= 0.0 or not ResourceLoader.exists("res://visual_effects/shader_noise_displacement.tres"):
		return null
	var gradient = Gradient.new()
	var mask = GradientTexture2D.new()
	mask.gradient = gradient
	mask.fill_from = Vector2(1, 0.85)
	var material = ShaderMaterial.new()
	material.shader = load("res://visual_effects/shader_noise_displacement.tres")
	material.set_shader_param("wave_speed", 0.6)
	material.set_shader_param("wave_size", 2.1)
	material.set_shader_param("wave_strenght", 0.06 * amount)
	material.set_shader_param("Mask", mask)
	return material


# Расстановка предметов (1.1.0, просьба пользователя 13.11: окружение не должно заходить на арену и
# пересекаться с персонажем). Раньше ставил генератор игры (кольца SpritesAroundTheZone), он считает
# от точки опоры и со случайным сдвигом, поэтому предметы заходили за контур. Теперь каждый предмет
# ставится от своего края: ни один пиксель спрайта не ближе GAP к прямоугольнику арены. Отступы малые
# (1.1.1: пользователь просил оставить окружение вплотную, только чтобы не заходило внутрь и не перекрывало персонажа).
const GAP_SIDE = 12.0    # слева и справа: слегка заходит на контур (он на ~30 снаружи зоны), как в джунглях, но не в саму арену
const GAP_TOP = 30.0     # сверху: опора у контура; персонаж ниже по высоте и рисуется поверх
const GAP_BOTTOM = 22.0  # снизу: верх спрайта сразу под контуром
const CORNER = 1000.0    # насколько ряды сверху и снизу уходят за углы арены (камера совместной игры)
# слои: [какие спрайты, цвет, доп. отступ от края, разброс отступа, шаг от, шаг до]
const LAYER_LOW = 0
const LAYER_BIG = 1
const LAYER_FAR = 2


func _place_props(container: Node, theme: Dictionary) -> void:
	var big = _textures(theme.dir, "big")
	var low = _textures(theme.dir, "low")
	if big.empty() or low.empty():
		ModLoaderLog.warning("No sprites for " + theme.dir, LOG_NAME)
		return
	var material = _sway_material(theme.sway)
	var zone: Rect2 = ZoneService.get_current_zone_rect()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	# дальний тёмный слой, высокие за низкими, низкие у самого края
	var deep = Color(theme.far.r * 0.72, theme.far.g * 0.72, theme.far.b * 0.72)
	var layers = [
		[big + low, deep, 600.0, 120.0, 140.0, 300.0, material],  # для отдалённой камеры совместной игры
		[big + low, theme.far, 220.0, 90.0, 110.0, 250.0, material],
		[big, theme.tint, 35.0, 55.0, 130.0, 290.0, material],
		[low, theme.tint, 0.0, 28.0, 150.0, 320.0, null],
	]
	var count = 0
	for layer in layers:
		var textures: Array = layer[0]
		# верх и низ: ряды вдоль всей ширины и за углы
		var x = zone.position.x - CORNER + rng.randf_range(0.0, layer[4])
		while x < zone.end.x + CORNER:
			var top_tex: Texture = textures[rng.randi() % textures.size()]
			# сверху: низ спрайта не ниже края минус отступ
			_add_prop(container, top_tex, Vector2(x, zone.position.y - GAP_TOP - layer[2] - rng.randf_range(0.0, layer[3])), layer[1], layer[6], rng)
			var bottom_tex: Texture = textures[rng.randi() % textures.size()]
			# снизу: верх спрайта не выше края плюс отступ (опора = низ спрайта)
			var top_edge = zone.end.y + GAP_BOTTOM + layer[2] * 0.6 + rng.randf_range(0.0, layer[3])
			_add_prop(container, bottom_tex, Vector2(x + rng.randf_range(-40.0, 40.0), top_edge + bottom_tex.get_height()), layer[1], layer[6], rng)
			x += rng.randf_range(layer[4], layer[5])
			count += 2
		# бока: столбцы между верхним и нижним рядами
		var y = zone.position.y + rng.randf_range(0.0, layer[4])
		while y < zone.end.y + 120.0:
			var left_tex: Texture = textures[rng.randi() % textures.size()]
			var left_edge = zone.position.x - GAP_SIDE - layer[2] - rng.randf_range(0.0, layer[3])
			_add_prop(container, left_tex, Vector2(left_edge - left_tex.get_width() / 2.0, y), layer[1], layer[6], rng)
			var right_tex: Texture = textures[rng.randi() % textures.size()]
			var right_edge = zone.end.x + GAP_SIDE + layer[2] + rng.randf_range(0.0, layer[3])
			_add_prop(container, right_tex, Vector2(right_edge + right_tex.get_width() / 2.0, y + rng.randf_range(-50.0, 50.0)), layer[1], layer[6], rng)
			y += rng.randf_range(layer[4], layer[5]) * 0.8
			count += 2
	ModLoaderLog.info("Borders placed for %s: %d props" % [theme.dir, count], LOG_NAME)


# Спрайт с опорой в середине низа: position = точка на земле, YSort рисует по ней.
static func _add_prop(container: Node, texture: Texture, base: Vector2, color: Color, material: Material, rng: RandomNumberGenerator) -> void:
	var sprite = Sprite.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())
	sprite.flip_h = rng.randi() % 2 == 0
	sprite.modulate = color
	sprite.material = material
	sprite.add_to_group("codex_arena_border")  # чтобы прятать разом (съёмка "было / стало")
	container.add_child(sprite)
	sprite.global_position = base
