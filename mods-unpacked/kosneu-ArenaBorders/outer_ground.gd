extends Node2D

# kosneu-ArenaBorders: земля за краем арены. Те же тайлы, что у арены (случайные клетки набора фона),
# затемнённые и темнеющие с расстоянием; рисуется под зубчатым контуром арены (ребёнок TileMap с
# show_behind_parent, первым среди детей). Клетки под самой ареной не рисуем. Один раз считаем
# раскладку, дальше это статичный набор прямоугольников одной текстуры.

const TILE = 64
# сколько клеток за край: по бокам больше (на широком экране телефона бока видны всегда)
const MARGIN_X = 19  # 1.1.4: в совместной игре камера отдаляется, на экране 20:9 по бокам видно ~1000 px
const MARGIN_TOP = 7
const MARGIN_BOTTOM = 9

var _texture: Texture = null
var _color: = Color(0.5, 0.5, 0.5)
var _cells = []  # [Rect2 куда, Rect2 откуда, Color]


func setup(tile_map: TileMap, texture: Texture, color: Color) -> void:
	_texture = texture
	_color = color
	show_behind_parent = true
	if texture == null:
		return
	var used = tile_map.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var columns = int(texture.get_width() / TILE)
	var rows = int(texture.get_height() / TILE)
	if columns <= 0 or rows <= 0:
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var x0 = int(used.position.x)
	var y0 = int(used.position.y)
	var x1 = int(used.end.x)
	var y1 = int(used.end.y)
	for y in range(y0 - MARGIN_TOP, y1 + MARGIN_BOTTOM):
		for x in range(x0 - MARGIN_X, x1 + MARGIN_X):
			# клетки арены, кроме крайних (контур зубчатый, под ним должна быть земля)
			if x > x0 and x < x1 - 1 and y > y0 and y < y1 - 1:
				continue
			var dx = max(max(x0 - x, x - (x1 - 1)), 0)
			var dy = max(max(y0 - y, y - (y1 - 1)), 0)
			var far = clamp(max(dx / float(MARGIN_X), dy / float(MARGIN_BOTTOM)), 0.0, 1.0)
			var k = lerp(1.0, 0.45, far)
			var source = Rect2(rng.randi() % columns * TILE, rng.randi() % rows * TILE, TILE, TILE)
			_cells.push_back([Rect2(x * TILE, y * TILE, TILE, TILE), source, Color(_color.r * k, _color.g * k, _color.b * k)])
	update()


func _draw() -> void:
	if _texture == null:
		return
	for cell in _cells:
		draw_texture_rect_region(_texture, cell[0], cell[1], cell[2])
