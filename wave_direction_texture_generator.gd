@tool
extends Line2D


@export_node_path("Line2D") var _wave_direction_line_path: NodePath
@export_node_path("Line2D") var _wave_force_line_path: NodePath
@export_node_path("Line2D") var _horizontal_sections_line_path: NodePath

@export_node_path("SubViewport") var _sub_viewport_path: NodePath

@export_range(0, 100) var _color_transition_part_size: int
@export_range(0.1, 1, 0.01) var _texture_clarity: float
@export var _horizontal_sections_count: int

var _wave_direction_line: Line2D
var _wave_force_line: Line2D
var _horizontal_sections_line: Line2D
var _sub_viewport: SubViewport

var _cached_points: PackedVector2Array
var _cached_color_transition_part_size: int
var _cached_texture_clarity: float
var _cached_horizontal_sections_count: int


func _process(delta: float) -> void:
	if (_wave_direction_line_path.is_empty()
	or _wave_force_line_path.is_empty()
	or _horizontal_sections_line_path.is_empty()):
		return
	
	if not _wave_direction_line:
		_wave_direction_line = get_node(_wave_direction_line_path)
	if not _wave_force_line:
		_wave_force_line = get_node(_wave_force_line_path)
	if not _horizontal_sections_line:
		_horizontal_sections_line = get_node(_horizontal_sections_line_path)
	if not _sub_viewport:
		_sub_viewport = get_node(_sub_viewport_path)
	
	if (_cached_points == points
	and _cached_color_transition_part_size == _color_transition_part_size
	and _cached_texture_clarity == _texture_clarity
	and _cached_horizontal_sections_count == _horizontal_sections_count):
		return
	
	_cached_points = points
	_cached_color_transition_part_size = _color_transition_part_size
	_cached_texture_clarity = _texture_clarity
	_cached_horizontal_sections_count = _horizontal_sections_count
	
	if points.is_empty():
		printerr("Points is empty!")
		return
	
	_update_wave_direction_line()
	_update_horizontal_sections_line()
	_update_wave_force_line()


func _update_wave_direction_line() -> void:
	_wave_direction_line.points = points
	_wave_direction_line.width = width
	_wave_direction_line.width_curve = width_curve
	
	var line_length: = _get_line_length(_wave_direction_line)
	var line_unit_path: = _get_line_unit_path(_wave_direction_line)
	
	var gradient_offsets = []
	var gradient_colors = []
	
	var prev_path_part_end: float
	for path_part in line_unit_path:
		prev_path_part_end += path_part.length()
		gradient_offsets.append(prev_path_part_end)
		
		var rg_values = path_part.normalized().rotated(-PI/2) / 2 + Vector2(0.5, 0.5)
		gradient_colors.append(Color(rg_values.x, rg_values.y, 0, 1))
	
	var result_offsets = []
	var result_colors = []
	
	var transition_part_unit_size = _color_transition_part_size / line_length
	var prev_offset: float
	for point_idx in range(gradient_offsets.size()):
		var offset = gradient_offsets[point_idx]
		var color = gradient_colors[point_idx]
		if offset - prev_offset < transition_part_unit_size:
			result_offsets.append(offset)
			result_colors.append(color)
			prev_offset = offset
			continue
		
		result_offsets.append(prev_offset + transition_part_unit_size / 2)
		result_colors.append(color)
		result_offsets.append(offset - transition_part_unit_size / 2)
		result_colors.append(color)
		
		prev_offset = offset
	
	var texture_size = Vector2(line_length, _wave_direction_line.width) * _texture_clarity
	
	var direction_gradient = Gradient.new()
	direction_gradient.offsets = result_offsets
	direction_gradient.colors = result_colors
	
	var direction_texture = GradientTexture2D.new()
	direction_texture.width = texture_size.x
	direction_texture.height = texture_size.y
	direction_texture.fill_from = Vector2.ZERO
	direction_texture.fill_to = Vector2.RIGHT
	direction_texture.gradient = direction_gradient
	
	var result_image = direction_texture.get_image()
	result_image.fill_rect(Rect2(Vector2(0, texture_size.y * 0.5), texture_size), Color.TRANSPARENT)
	
	_wave_direction_line.texture = ImageTexture.create_from_image(result_image)


func _update_horizontal_sections_line() -> void:
	_horizontal_sections_line.points = points
	_horizontal_sections_line.width = width
	_horizontal_sections_line.width_curve = width_curve
	
	var line_length: = _get_line_length(_horizontal_sections_line)
	var texture_size = Vector2(line_length, _horizontal_sections_line.width) * _texture_clarity
	
	var result_offsets: Array[float]
	var result_colors: Array[Color]
	var horizontal_section_unit_length = 1.0 / _horizontal_sections_count
	for point_idx in range(_horizontal_sections_count + 1):
		var offset = horizontal_section_unit_length * point_idx
		
		if point_idx != 0:
			result_offsets.append(offset)
			result_colors.append(Color.BLACK)
		
		result_offsets.append(offset)
		result_colors.append(Color.WHITE)
	
	var gradient = Gradient.new()
	gradient.offsets = [0, 1]
	gradient.colors = [Color.BLACK, Color.WHITE]
	
	var texture = GradientTexture1D.new()
	var section_length = float(texture_size.x) / _horizontal_sections_count
	texture.width = section_length
	texture.gradient = gradient
	var texture_image = texture.get_image()
	
	var image = Image.create(texture_size.x, 1, false, texture_image.get_format())
	image.fill(Color.BLACK)
	
	var src_rect = Rect2(Vector2.ZERO, texture_image.get_size())
	var fill_position = Vector2.ZERO
	for section_idx in _horizontal_sections_count:
		image.blend_rect(texture_image, src_rect, fill_position)
		fill_position.x += section_length
	
	_horizontal_sections_line.texture = ImageTexture.create_from_image(image)


func _update_wave_force_line() -> void:
	_wave_force_line.points = points
	_wave_force_line.width = width
	_wave_force_line.width_curve = width_curve


func _get_line_length(line: Line2D) -> float:
	var line_length: float
	var prev_point: Vector2
	for point in line.points:
		if prev_point:
			line_length += (point - prev_point).length()
		
		prev_point = point
	
	return line_length


func _get_line_unit_path(line: Line2D) -> Array[Vector2]:
	var line_length = _get_line_length(line)
	
	var unit_path: Array[Vector2]
	
	var prev_point: Vector2
	for point in line.points:
		if prev_point:
			var segment = point - prev_point
			var unit_segment = segment.normalized() * (segment.length() / line_length)
			unit_path.append(unit_segment)
		
		prev_point = point
	
	return unit_path


class GradientPoint:
	var offset: float
	var color: Color
	
	func _init(offset: float, color: Color) -> void:
		self.offset = offset
		self.color = color
