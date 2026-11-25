class_name Prof
## Tiny opt-in timer for per-frame systems (profiling builds only).
static var on := false
static var acc := {}
static var cnt := {}

static func add(key: String, t0: int) -> void:
	acc[key] = acc.get(key, 0) + Time.get_ticks_usec() - t0
	cnt[key] = cnt.get(key, 0) + 1
