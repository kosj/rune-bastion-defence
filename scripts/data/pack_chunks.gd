class_name PackChunks
## Download chunks of the web build: which asset lives in which pack, in download order.
## Single source of truth for tools/split_pck.py (reads the JSON between the CHUNKS markers),
## tools/package_web.py (chunk order for the page) and the Content autoload (what is mounted).
##
##   core   index.pck            engine data, scripts, fonts, UI kit, the default title picture,
##                               the menu click sounds: everything the title screen needs
##   menu   index_menu.pck       world map, level / tower / character pictures, voices, sound
##                               effects, the menu music, the other heroes' title pictures
##   stage1 index_stage1.pck     the first battle (level 1 with Kael): terrain, effects, props,
##                               castle, portal, level-1 towers and their crews, its enemies
##   towers index_towers.pck     tower levels 2-3 (upgrades) and the troll: completes the 3D title
##   world  index_world.pck      everything else: later enemies, bosses, the other heroes
##
## Rules (checked by tools/split_pck.py and tools/check_chunks.sh):
## - a chunk may only refer to assets of the same or an earlier chunk;
## - nothing loads a chunk's asset before Content says that chunk is mounted
##   (Content.ensure / Content.has / Content.allows);
## - patterns are globs (* and ?) on the source path; the first chunk in "match" that matches
##   wins, anything unmatched stays in core.
## Keep core small: every byte in it delays the title screen on a first visit. budget_mb caps the
## desktop chunks (MB, uncompressed); split_pck.py fails the build when one grows past its cap.

const DATA := {
	# CHUNKS-JSON-BEGIN
	"order": ["core", "menu", "stage1", "towers", "world"],
	"match": ["core", "world", "towers", "menu", "stage1"],
	"chunks": {
		"core": [
			"assets/audio/sfx/click.*", "assets/audio/sfx/error.*", "assets/audio/sfx/sell.*",
			"assets/audio/sfx/upgrade.*", "assets/audio/sfx/tick.*"
		],
		"menu": [
			"assets/ui/world_map.*", "assets/ui/level_*", "assets/ui/portrait_*", "assets/ui/tower_*",
			"assets/ui/backdrop/menu_sera.*", "assets/ui/backdrop/menu_ranger.*",
			"assets/audio/voice/*", "assets/audio/sfx/*", "assets/audio/music/menu.*"
		],
		"stage1": [
			"assets/models/*", "assets/characters/*", "assets/fx/*", "assets/textures/*",
			"assets/audio/music/battle.*"
		],
		"towers": [
			"assets/models/archer_2*", "assets/models/archer_3*", "assets/models/mage_2*",
			"assets/models/mage_3*", "assets/models/barracks_2*", "assets/models/barracks_3*",
			"assets/models/artillery_2*", "assets/models/artillery_3*", "assets/characters/troll*"
		],
		"world": [
			"assets/characters/lich*", "assets/characters/sera*", "assets/characters/ranger*",
			"assets/characters/ogre*", "assets/characters/skeleton*", "assets/characters/gargoyle*",
			"assets/characters/sapper*", "assets/audio/music/battle_dark.*", "assets/audio/music/battle_river.*",
			"assets/audio/music/battle_night.*", "assets/audio/music/boss.*"
		]
	},
	"first_battle": {"level": 0, "hero": "kael", "needs": ["menu", "stage1"]},
	"title_3d_needs": ["stage1", "towers"],
	"budget_mb": {"core": 3.5, "menu": 7.0, "stage1": 40.0}
	# CHUNKS-JSON-END
}

## Chunk of a source path ("res://assets/models/castle.glb" or "assets/models/castle.glb").
static func chunk_of(path: String) -> String:
	var p := path.trim_prefix("res://")
	for c in DATA["match"]:
		for pat in DATA["chunks"][c]:
			if p.match(pat):
				return c
	return "core"
