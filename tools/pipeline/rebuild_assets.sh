#!/bin/bash
# Rebuild every game-ready 3D asset from the raw VARCO downloads (see tools/pipeline/*.py).
#   structures: high-poly regen (dl_hq) -> decimate + weighted normals + normal/AO bake
#   props:      phase-2 raw meshes      -> same pipeline, smaller budgets
#   characters: rigged per-animation GLBs -> merged clips, AO bake in rest pose, cleaned ORM
# usage: rebuild_assets.sh OUT_DIR   (then copy OUT_DIR/*.glb into assets/models|characters)
set -e
H=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-/tmp/assets_out}
RAW=${RAW:-/home/claude}
mkdir -p "$OUT/models" "$OUT/characters"
M="$OUT/models/meta.json"
blender -b -P "$H/process_hq.py" -- "$RAW/dl_hq" "$OUT/models" "$M" \
 archer_1:tower:2.9:14000:1024:512:hard:256 archer_2:tower:3.1:16000:1024:512:hard:256 archer_3:tower:3.3:20000:1024:512:hard:256 \
 barracks_1:tower:3.5:14000:1024:512:hard:256 barracks_2:tower:3.7:16000:1024:512:hard:256 barracks_3:tower:3.9:20000:1024:512:hard:256 \
 mage_1:tower:3.0:14000:1024:512:hard:256 mage_2:tower:3.2:16000:1024:512:hard:256 mage_3:tower:3.4:20000:1024:512:hard:256 \
 artillery_1:tower:3.2:14000:1024:512:hard:256 artillery_2:tower:3.4:16000:1024:512:hard:256 artillery_3:tower:3.6:20000:1024:512:hard:256 \
 castle:foot:10.5:30000:2048:1024:hard:512 portal:foot:7.0:24000:1024:1024:hard:512 plot:foot:3.6:3000:1024:512:hard:256 \
 2>&1 | grep -E "^(BAKE|DONE|AO|ORM)|Traceback|Error"
blender -b -P "$H/process_hq.py" -- "$RAW/props_in" "$OUT/models" "$M" \
 tree_round_v:height:4.6:4000:1024:512:soft:256 tree_pine_v:height:5.2:3400:1024:512:soft:256 rocks_v:foot:2.2:1500:512:256:soft:256 \
 bush:foot:1.9:3200:512:256:soft:256 house:foot:4.6:3000:1024:512:hard:256 lamp:height:2.7:1200:512:256:hard:256 \
 barrels:foot:1.9:2000:512:256:hard:256 crystals:height:1.7:1500:512:256:hard:256 fence:foot:2.8:1200:512:256:hard:256 \
 bridge:foot:8.0:3500:1024:512:hard:256 flowers:foot:1.3:1500:512:256:soft:256 \
 2>&1 | grep -E "^(BAKE|DONE|AO|ORM)|Traceback|Error"
A4=$RAW/varco/anim_v4; A=$RAW/varco/anim; A5=$RAW/varco/anim_v5; D2=$RAW/dl_v2; D3=$RAW/dl_v3; C="$OUT/characters"
mc() { local np=$1; shift; NORMAL_PX=$np blender -b -P "$H/merge_character.py" -- "$@" 2>&1 | grep -E "^(WROTE|AO|ORM)|Traceback|Error"; }
mc 256 $C/footman.glb 1024 idle=$A/footman_idle.glb run=$A/footman_run.glb attack=$A/footman_attack.glb death=$A/footman_death.glb hit=$A5/footman_hit.glb cheer=$A5/footman_cheer.glb
mc 256 $C/goblin.glb 1024 run=$A/goblin_run.glb attack=$A/goblin_attack.glb death=$A/goblin_death.glb hit=$A5/goblin_hit.glb death2=$A5/goblin_death2.glb
mc 512 $C/hero.glb 1024 idle=$A/hero_idle.glb run=$A/hero_run.glb attack=$A/hero_attack.glb skill=$A/hero_skill.glb death=$A/hero_death.glb cheer=$A/hero_cheer.glb hit=$A5/hero_hit.glb
mc 256 $C/orc.glb 1024 run=$A/orc_run.glb attack=$A/orc_attack.glb death=$A/orc_death.glb hit=$A5/orc_hit.glb
mc 256 $C/troll.glb 1024 run=$A/troll_run.glb attack=$A/troll_attack.glb death=$A/troll_death.glb roar=$A/troll_roar.glb taunt=$A5/troll_taunt.glb
mc 256 $C/gargoyle.glb 1024 idle=$RAW/varco/raw/gargoyle.glb
mc 256 $C/wolf.glb 1024 run=$A5/wolf_run.glb death=$A5/wolf_death.glb
mc 256 $C/archer_unit.glb 1024 idle=$D2/archer_anim_a.glb attack=$D2/archer_anim_b.glb
mc 256 $C/mage_unit.glb 1024 idle=$D2/mage_idle.glb attack=$D2/mage_cast.glb
mc 256 $C/sapper.glb 1024 run=$D3/sapper_run.glb attack=$D3/sapper_attack.glb death=$D3/sapper_death.glb hit=$A5/sapper_hit.glb
mc 256 $C/ogre.glb 1024 run=$D3/ogre_run.glb attack=$D3/ogre_attack.glb death=$D3/ogre_death.glb roar=$D3/ogre_roar.glb
mc 512 $C/sera.glb 1024 idle=$D3/sera_idle.glb run=$D3/sera_run.glb attack=$D3/sera_attack.glb skill=$D3/sera_skill.glb death=$D3/sera_death.glb cheer=$D3/sera_cheer.glb hit=$A5/sera_hit.glb
mc 256 $C/skeleton_knight.glb 1024 run=$A4/skeleton_knight_run.glb attack=$A4/skeleton_knight_attack.glb death=$A4/skeleton_knight_death.glb hit=$A5/skeleton_knight_hit.glb rise=$A5/skeleton_knight_rise_supine.glb
mc 512 $C/lich.glb 1024 run=$A4/lich_walk.glb attack=$A4/lich_attack.glb death=$A4/lich_death.glb roar=$A4/lich_summon.glb taunt=$A5/lich_taunt.glb cast=$A5/lich_cast.glb
echo ALL_DONE
