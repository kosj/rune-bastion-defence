class_name Lang
## Localisation. Korean is the source language (every string in the code is the Korean original);
## English comes from a runtime Translation built from LangEN.T. Controls translate their text
## automatically; formatted strings go through tr()/Lang.t() on the format pattern.

static var _en: Translation

## code: "" = follow the browser / OS language (Korean for ko-*, English otherwise), "ko", "en".
static func apply(code: String) -> void:
	if _en == null:
		_en = Translation.new()
		_en.locale = "en"
		for k in LangEN.T:
			_en.add_message(k, LangEN.T[k])
		for ctx in LangEN.C:
			for k in LangEN.C[ctx]:
				_en.add_message(k, LangEN.C[ctx][k], ctx)
	var loc := code
	if loc == "":
		loc = "ko" if OS.get_locale_language() == "ko" else "en"
	# the English table is only registered while English is active: with Korean selected there is
	# nothing for the TranslationServer's fallback locale (en) to leak into the Korean UI
	TranslationServer.remove_translation(_en)
	if loc == "en":
		TranslationServer.add_translation(_en)
	TranslationServer.set_locale(loc)
	if OS.has_feature("web"):
		# the HTML loading screen reads this before the engine starts
		JavaScriptBridge.eval("try{localStorage.setItem('rb_lang','%s')}catch(e){}" % loc)

static func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)

static func is_en() -> bool:
	return current() == "en"

static func t(s: String) -> String:
	return TranslationServer.translate(s)
