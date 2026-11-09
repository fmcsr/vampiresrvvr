class_name IronFrame
extends StyleBox
## Dark iron plate with a gold trim line and small corner ornaments, drawn in code. UiTheme uses
## it in different colors for panels, cards, buttons and item or power slots.

## Fill color at the top and at the bottom (a vertical gradient).
var fill_top := Color(0.105, 0.095, 0.085, 0.97)
var fill_bottom := Color(0.055, 0.05, 0.045, 0.97)
## Dark outer edge.
var edge := Color(0.0, 0.0, 0.0, 0.85)
var edge_width := 2.0
## Inner trim line, drawn inset from the edge.
var trim := Color(0.62, 0.5, 0.3)
var trim_width := 1.0
var trim_inset := 4.0
## Length of the corner brackets; 0 draws plain corners.
var corner := 9.0
## Soft light along the inside of the trim (hover, selected); transparent for none.
var glow := Color(0.0, 0.0, 0.0, 0.0)
var glow_depth := 10.0
## Strength of the mottled texture over the fill.
var grain := 0.06

static var _grain_texture: Texture2D


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var server := RenderingServer
	server.canvas_item_add_polygon(to_canvas_item, _corners(rect),
			PackedColorArray([fill_top, fill_top, fill_bottom, fill_bottom]))
	if grain > 0.0:
		server.canvas_item_add_texture_rect(to_canvas_item, rect, _grain().get_rid(), false, Color(1.0, 1.0, 1.0, grain))
	var inner := rect.grow(-trim_inset)
	if glow.a > 0.0 and inner.size.x > 2.0 * glow_depth and inner.size.y > 2.0 * glow_depth:
		_draw_glow(to_canvas_item, inner)
	if edge_width > 0.0:
		_outline(to_canvas_item, rect.grow(-edge_width * 0.5), edge, edge_width)
	if trim.a > 0.0 and inner.size.x > 0.0 and inner.size.y > 0.0:
		_outline(to_canvas_item, inner, trim, trim_width)
		if corner > 0.0:
			_draw_corners(to_canvas_item, inner)


## Light fading inward from the trim on all four sides.
func _draw_glow(item: RID, inner: Rect2) -> void:
	var outer := _corners(inner)
	var deep := _corners(inner.grow(-glow_depth))
	var clear := Color(glow, 0.0)
	for i in 4:
		var next := (i + 1) % 4
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([outer[i], outer[next], deep[next], deep[i]]),
				PackedColorArray([glow, glow, clear, clear]))


## Brackets along both edges from each corner, with a small diamond on the corner itself.
func _draw_corners(item: RID, inner: Rect2) -> void:
	var length := minf(corner, minf(inner.size.x, inner.size.y) * 0.3)
	var bright := trim.lightened(0.25)
	var points := _corners(inner)
	var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var point := points[i]
		var direction := inward[i]
		RenderingServer.canvas_item_add_line(item, point, point + Vector2(direction.x * length, 0.0), bright, trim_width + 1.0)
		RenderingServer.canvas_item_add_line(item, point, point + Vector2(0.0, direction.y * length), bright, trim_width + 1.0)
		var half := clampf(length * 0.3, 2.0, 5.0)
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([point + Vector2(0.0, -half),
				point + Vector2(half, 0.0), point + Vector2(0.0, half), point + Vector2(-half, 0.0)]), PackedColorArray([bright]))


func _outline(item: RID, rect: Rect2, color: Color, width: float) -> void:
	var points := _corners(rect)
	points.append(points[0])
	RenderingServer.canvas_item_add_polyline(item, points, PackedColorArray([color]), width)


## Top-left, top-right, bottom-right, bottom-left.
static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## White noise with a soft alpha, stretched over the plate so it looks like worn metal.
static func _grain() -> Texture2D:
	if _grain_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.06
		noise.fractal_octaves = 4
		var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var value := noise.get_noise_2d(x, y) * 0.5 + 0.5
				image.set_pixel(x, y, Color(1.0, 0.95, 0.85, clampf((value - 0.35) * 1.6, 0.0, 1.0)))
		_grain_texture = ImageTexture.create_from_image(image)
	return _grain_texture
