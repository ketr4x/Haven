@tool
class_name CrtOverlay
extends CanvasLayer

@export_group("Curvature")
@export_range(0.0, 0.6, 0.005) var curvature_x: float = 0.11:
	set(value):
		curvature_x = value
		_apply_shader_parameters()
@export_range(0.0, 0.6, 0.005) var curvature_y: float = 0.14:
	set(value):
		curvature_y = value
		_apply_shader_parameters()
@export_range(0.85, 1.15, 0.005) var screen_scale: float = 0.995:
	set(value):
		screen_scale = value
		_apply_shader_parameters()
@export_range(0.0, 0.4, 0.005) var glass_bulge: float = 0.04:
	set(value):
		glass_bulge = value
		_apply_shader_parameters()

@export_group("Vignette & Rounded Corners")
@export_range(0.0, 0.4, 0.005) var corner_radius: float = 0.085:
	set(value):
		corner_radius = value
		_apply_shader_parameters()
@export_range(0.001, 0.08, 0.001) var corner_smoothness: float = 0.012:
	set(value):
		corner_smoothness = value
		_apply_shader_parameters()
@export_range(0.0, 2.0, 0.01) var vignette_intensity: float = 0.36:
	set(value):
		vignette_intensity = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var vignette_opacity: float = 0.82:
	set(value):
		vignette_opacity = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var vignette_roundness: float = 0.30:
	set(value):
		vignette_roundness = value
		_apply_shader_parameters()
@export_range(0.0, 0.3, 0.005) var bezel_reflection: float = 0.05:
	set(value):
		bezel_reflection = value
		_apply_shader_parameters()
@export var bezel_color: Color = Color(0.012, 0.012, 0.018, 1.0):
	set(value):
		bezel_color = value
		_apply_shader_parameters()

@export_group("Scanlines")
@export_range(60.0, 1080.0, 1.0) var scanline_count: float = 240.0:
	set(value):
		scanline_count = value
		_apply_shader_parameters()
@export_range(0.25, 3.0, 0.05) var scanline_density: float = 1.0:
	set(value):
		scanline_density = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var scanline_opacity: float = 0.44:
	set(value):
		scanline_opacity = value
		_apply_shader_parameters()
@export_range(0.5, 4.0, 0.05) var scanline_sharpness: float = 1.5:
	set(value):
		scanline_sharpness = value
		_apply_shader_parameters()
@export_range(0.0, 0.6, 0.01) var scanline_brightness_boost: float = 0.20:
	set(value):
		scanline_brightness_boost = value
		_apply_shader_parameters()
@export_range(-10.0, 10.0, 0.1) var scanline_scroll_speed: float = 0.0:
	set(value):
		scanline_scroll_speed = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.05) var scanline_curvature_follow: float = 1.0:
	set(value):
		scanline_curvature_follow = value
		_apply_shader_parameters()

@export_group("Shadow Mask / CRT Grid")
@export_range(0.0, 1.0, 0.01) var mask_intensity: float = 0.45:
	set(value):
		mask_intensity = value
		_apply_shader_parameters()
@export_range(0.5, 4.0, 0.1) var mask_scale: float = 1.5:
	set(value):
		mask_scale = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var mask_grid_strength: float = 0.55:
	set(value):
		mask_grid_strength = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var mask_bright_boost: float = 0.75:
	set(value):
		mask_bright_boost = value
		_apply_shader_parameters()

@export_group("Chromatic Aberration")
@export_range(0.0, 12.0, 0.1) var aberration_offset: float = 2.8:
	set(value):
		aberration_offset = value
		_apply_shader_parameters()
@export_range(0.5, 4.0, 0.05) var aberration_edge_power: float = 1.55:
	set(value):
		aberration_edge_power = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var aberration_center_weight: float = 0.25:
	set(value):
		aberration_center_weight = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var color_bleed_strength: float = 0.58:
	set(value):
		color_bleed_strength = value
		_apply_shader_parameters()
@export_range(0.0, 6.0, 0.1) var edge_blur_radius: float = 2.0:
	set(value):
		edge_blur_radius = value
		_apply_shader_parameters()

@export_group("Bloom / Glow")
@export_range(0.0, 2.0, 0.01) var bloom_intensity: float = 0.55:
	set(value):
		bloom_intensity = value
		_apply_shader_parameters()
@export_range(0.0, 1.0, 0.01) var bloom_threshold: float = 0.34:
	set(value):
		bloom_threshold = value
		_apply_shader_parameters()
@export_range(0.01, 0.5, 0.01) var bloom_soft_knee: float = 0.20:
	set(value):
		bloom_soft_knee = value
		_apply_shader_parameters()
@export_range(0.5, 8.0, 0.1) var bloom_radius: float = 3.2:
	set(value):
		bloom_radius = value
		_apply_shader_parameters()
@export_range(0.8, 1.6, 0.01) var brightness_boost: float = 1.15:
	set(value):
		brightness_boost = value
		_apply_shader_parameters()

@onready var _crt_rect: ColorRect = $CrtRect


func _ready() -> void:
	if _crt_rect != null and _crt_rect.material != null and not Engine.is_editor_hint():
		_crt_rect.material = _crt_rect.material.duplicate()
	_apply_shader_parameters()


func get_shader_material() -> ShaderMaterial:
	var rect := get_node_or_null("CrtRect") as ColorRect
	if rect == null:
		return null
	return rect.material as ShaderMaterial


func _apply_shader_parameters() -> void:
	var shader_material := get_shader_material()
	if shader_material == null:
		return
	shader_material.set_shader_parameter("curvature_x", curvature_x)
	shader_material.set_shader_parameter("curvature_y", curvature_y)
	shader_material.set_shader_parameter("screen_scale", screen_scale)
	shader_material.set_shader_parameter("glass_bulge", glass_bulge)
	shader_material.set_shader_parameter("corner_radius", corner_radius)
	shader_material.set_shader_parameter("corner_smoothness", corner_smoothness)
	shader_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	shader_material.set_shader_parameter("vignette_opacity", vignette_opacity)
	shader_material.set_shader_parameter("vignette_roundness", vignette_roundness)
	shader_material.set_shader_parameter("bezel_reflection", bezel_reflection)
	shader_material.set_shader_parameter("bezel_color", bezel_color)
	shader_material.set_shader_parameter("scanline_count", scanline_count)
	shader_material.set_shader_parameter("scanline_density", scanline_density)
	shader_material.set_shader_parameter("scanline_opacity", scanline_opacity)
	shader_material.set_shader_parameter("scanline_sharpness", scanline_sharpness)
	shader_material.set_shader_parameter("scanline_brightness_boost", scanline_brightness_boost)
	shader_material.set_shader_parameter("scanline_scroll_speed", scanline_scroll_speed)
	shader_material.set_shader_parameter("scanline_curvature_follow", scanline_curvature_follow)
	shader_material.set_shader_parameter("mask_intensity", mask_intensity)
	shader_material.set_shader_parameter("mask_scale", mask_scale)
	shader_material.set_shader_parameter("mask_grid_strength", mask_grid_strength)
	shader_material.set_shader_parameter("mask_bright_boost", mask_bright_boost)
	shader_material.set_shader_parameter("aberration_offset", aberration_offset)
	shader_material.set_shader_parameter("aberration_edge_power", aberration_edge_power)
	shader_material.set_shader_parameter("aberration_center_weight", aberration_center_weight)
	shader_material.set_shader_parameter("color_bleed_strength", color_bleed_strength)
	shader_material.set_shader_parameter("edge_blur_radius", edge_blur_radius)
	shader_material.set_shader_parameter("bloom_intensity", bloom_intensity)
	shader_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	shader_material.set_shader_parameter("bloom_soft_knee", bloom_soft_knee)
	shader_material.set_shader_parameter("bloom_radius", bloom_radius)
	shader_material.set_shader_parameter("brightness_boost", brightness_boost)
