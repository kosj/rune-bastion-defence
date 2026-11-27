class_name Lang
## Localisation. Korean is the source language (every string in the code is the Korean original);
## English comes from a runtime Translation built from LangEN.T. Controls translate their text
## automatically; formatted strings go through tr()/Lang.t() on the format pattern.

static var _en: Translation
static var _ja: Translation
static var _want := ""     # the language asked for (ja may wait for its font)
static var _waiting := false

static func _table(locale: String, t: Dictionary, c: Dictionary) -> Translation:
	var tr_ := Translation.new()
	tr_.locale = locale
	for k in t:
		tr_.add_message(k, t[k])
	for ctx in c:
		for k in c[ctx]:
			tr_.add_message(k, c[ctx][k], ctx)
	return tr_

## code: "" = follow the browser / OS language (Korean for ko-*, Japanese for ja-*, English
## otherwise), "ko", "en", "ja".
static func apply(code: String) -> void:
	if _en == null:
		_en = _table("en", LangEN.T, LangEN.C)
		_ja = _table("ja", LangJA.T, LangJA.C)
	var loc := code
	if loc == "":
		var os := OS.get_locale_language()
		loc = os if os in ["ko", "ja"] else "en"
	_want = loc
	if loc == "ja" and not Assets.add_ja_font():
		# the Japanese font comes with the "menu" download chunk: English until it has arrived
		loc = "en"
		if not _waiting:
			_waiting = true
			Content.chunk_ready.connect(_on_chunk)
	# a table is only registered while its language is active: with Korean selected there is
	# nothing for the TranslationServer's fallback locale (en) to leak into the Korean UI.
	# Japanese keeps English underneath for any line it does not have.
	TranslationServer.remove_translation(_en)
	TranslationServer.remove_translation(_ja)
	if loc == "en" or loc == "ja":
		TranslationServer.add_translation(_en)
	if loc == "ja":
		TranslationServer.add_translation(_ja)
	TranslationServer.set_locale(loc)
	if OS.has_feature("web"):
		# the HTML loading screen reads this before the engine starts
		JavaScriptBridge.eval("try{localStorage.setItem('rb_lang','%s')}catch(e){}" % _want)

static func _on_chunk(chunk: String) -> void:
	if _want == "ja" and Assets.add_ja_font():
		_waiting = false
		Content.chunk_ready.disconnect(_on_chunk)
		apply("ja")

static func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)

static func is_en() -> bool:
	return current() == "en"

static func t(s: String) -> String:
	return TranslationServer.translate(s)
