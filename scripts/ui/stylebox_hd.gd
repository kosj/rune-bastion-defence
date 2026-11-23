class_name StyleBoxHD
extends StyleBox
## 9-slice StyleBox for textures authored at `px_scale` texels per canvas unit (the UI kit is drawn at
## 2x, so frames stay crisp when the 1280x720 / 960x540 canvas is stretched to 1.5-3x on real screens).
## Unlike StyleBoxTexture, source and on-screen margins are decoupled, and the corners shrink together
## when the box is smaller than its margins (round slots of any size use one texture).

var texture: Texture2D
var px_scale := 2.0
var margins := Vector4(16, 16, 16, 16)  # left, top, right, bottom in canvas units
var expand := Vector4.ZERO  # draw beyond the control rect (baked drop shadows / 3D button base)
var draw_center := true
var modulate_color := Color.WHITE

func _draw(ci: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var r := Rect2(rect.position - Vector2(expand.x, expand.y), rect.size + Vector2(expand.x + expand.z, expand.y + expand.w))
	var k := minf(1.0, minf(r.size.x / maxf(margins.x + margins.z, 0.001), r.size.y / maxf(margins.y + margins.w, 0.001)))
	var ts := texture.get_size()
	var xs := [r.position.x, r.position.x + margins.x * k, r.end.x - margins.z * k, r.end.x]
	var ys := [r.position.y, r.position.y + margins.y * k, r.end.y - margins.w * k, r.end.y]
	var us := [0.0, margins.x * px_scale, ts.x - margins.z * px_scale, ts.x]
	var vs := [0.0, margins.y * px_scale, ts.y - margins.w * px_scale, ts.y]
	var rid := texture.get_rid()
	for j in 3:
		for i in 3:
			if i == 1 and j == 1 and not draw_center:
				continue
			var dst := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if dst.size.x <= 0.01 or dst.size.y <= 0.01:
				continue
			var src := Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j])
			RenderingServer.canvas_item_add_texture_rect_region(ci, dst, rid, src, modulate_color)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position - Vector2(expand.x, expand.y), rect.size + Vector2(expand.x + expand.z, expand.y + expand.w))
