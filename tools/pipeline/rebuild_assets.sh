#!/bin/bash
# Rebuild every game-ready 3D asset from the raw VARCO downloads (see tools/pipeline/*.py).
# Triangle budgets come from the game camera: "e1.0" = the smallest mesh whose deviation from the
# high-poly stays under 1 px at the closest zoom (process_hq.py: 81.7 px/m at 900 px). Fewer
# triangles show as dented silhouettes and torn foliage up close; more are invisible there and the
# engine's automatic LODs drop them when zoomed out. Phones: "e1.6" (smaller, 0.8-scaled view).
#   structures: high-poly regen (dl_hq) -> decimate + weighted normals + normal/AO bake
#   props:      high-poly regen (dl_hq_props, 30k-60k) -> same pipeline. Props are drawn as
#               MultiMeshes, so the many-instance ones carry caps (e1.0/10000); past the 1 px target
#               the leaf bumps live on in the baked normal map. ALBEDO_REF keeps the colours of the
#               first-generation props (the regenerated pine came out a lot lighter).
#   characters: rigged per-animation GLBs -> merged clips, AO bake in rest pose, cleaned ORM
# usage: rebuild_assets.sh OUT_DIR   (then copy OUT_DIR/*.glb into assets/models|characters)
set -e
H=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-/tmp/assets_out}
RAW=${RAW:-/home/claude}
mkdir -p "$OUT/models" "$OUT/characters"
M="$OUT/models/meta.json"
blender -b -P "$H/process_hq.py" -- "$RAW/dl_hq" "$OUT/models" "$M" \
 archer_1:tower:2.9:e1.0:1024:512:hard:256 archer_2:tower:3.1:e1.0:1024:512:hard:256 archer_3:tower:3.3:e1.0:1024:512:hard:256 \
 barracks_1:tower:3.5:e1.0:1024:512:hard:256 barracks_2:tower:3.7:e1.0:1024:512:hard:256 barracks_3:tower:3.9:e1.0:1024:512:hard:256 \
 mage_1:tower:3.0:e1.0:1024:512:hard:256 mage_2:tower:3.2:e1.0:1024:512:hard:256 mage_3:tower:3.4:e1.0:1024:512:hard:256 \
 artillery_1:tower:3.2:e1.0:1024:512:hard:256 artillery_2:tower:3.4:e1.0:1024:512:hard:256 artillery_3:tower:3.6:e1.0:1024:512:hard:256 \
 castle:foot:10.5:e1.0:2048:1024:hard:512 portal:foot:7.0:e1.0:1024:1024:hard:512 plot:foot:3.6:e1.0:1024:512:hard:256 \
 2>&1 | grep -E "^(BAKE|DONE|AO|ORM)|Traceback|Error"
ALBEDO_REF="$RAW/props_in" blender -b -P "$H/process_hq.py" -- "$RAW/dl_hq_props" "$OUT/models" "$M" \
 tree_round_v:height:4.6:e1.0/10000:1024:512:soft:256 tree_pine_v:height:5.2:e1.0/8000:1024:512:soft:256 \
 rocks_v:foot:2.2:e1.0/3500:512:256:soft:256 bush:foot:1.9:e1.0/6000:512:256:soft:256 \
 house:foot:4.6:e1.0/10000:1024:512:hard:256 lamp:height:2.7:e1.0:512:256:hard:256 \
 barrels:foot:1.9:e1.0/5000:512:256:hard:256 crystals:height:1.7:e1.0:512:256:hard:256 fence:foot:2.8:e1.0:512:256:hard:256 \
 bridge:foot:8.0:e1.0:1024:512:hard:256 flowers:foot:1.3:e1.0/5000:512:256:soft:256 \
 2>&1 | grep -E "^(BAKE|DONE|AO|ORM)|Traceback|Error"
# held props and small set pieces (VARCO image-to-3D, grip/centre pivot + yaw so blades face +X and
# the mortar's muzzle faces +Z in Godot): name:mode:size:tris:albedo:normal:style:orm:pivot:yaw
blender -b -P "$H/process_hq.py" -- "$RAW/weapons_in/raw" "$OUT/models" "$M" \
 w_sword:height:1.44:800:512:512:hard:256:0.15:0 w_axe:height:1.34:800:512:512:hard:256:0.2:90 \
 w_club:height:1.85:900:512:512:soft:256:0.13:0 w_dagger:height:0.58:600:512:256:hard:256:0.2:0 \
 mortar:foot:1.25:1800:1024:512:hard:256:0:180 meteor:foot:1.4:900:512:512:soft:256:0.5:0 \
 shaman_crystal:height:1.1:900:512:512:hard:256:0.12:0 mage_crystal:height:1.0:700:512:512:hard:256:0.5:0 \
 2>&1 | grep -E "^(DONE)|Traceback|Error"
python3 "$H/make_emit.py" "$OUT/models"
# phone meshes for the mobile pack (mobile/models, swapped in by tools/build_web.sh)
MOB=${MOB_OUT:-$OUT/mobile_models}
blender -b -P "$H/process_hq.py" -- "$RAW/dl_hq" "$MOB" "$MOB/meta.json" \
 archer_1:tower:2.9:e1.6:512:256:hard:256 archer_2:tower:3.1:e1.6:512:256:hard:256 archer_3:tower:3.3:e1.6:512:256:hard:256 \
 barracks_1:tower:3.5:e1.6:512:256:hard:256 barracks_2:tower:3.7:e1.6:512:256:hard:256 barracks_3:tower:3.9:e1.6:512:256:hard:256 \
 mage_1:tower:3.0:e1.6:512:256:hard:256 mage_2:tower:3.2:e1.6:512:256:hard:256 mage_3:tower:3.4:e1.6:512:256:hard:256 \
 artillery_1:tower:3.2:e1.6:512:256:hard:256 artillery_2:tower:3.4:e1.6:512:256:hard:256 artillery_3:tower:3.6:e1.6:512:256:hard:256 \
 castle:foot:10.5:e1.6:1024:512:hard:256 portal:foot:7.0:e1.6:1024:512:hard:256 \
 2>&1 | grep -E "^(DONE)|Traceback|Error"
# props are drawn as MultiMeshes (one LOD choice for all instances): phones get lighter copies too
ALBEDO_REF="$RAW/props_in" blender -b -P "$H/process_hq.py" -- "$RAW/dl_hq_props" "$MOB" "$MOB/meta.json" \
 tree_round_v:height:4.6:e1.6/6500:1024:512:soft:256 tree_pine_v:height:5.2:e1.6/8000:1024:512:soft:256 \
 rocks_v:foot:2.2:e1.6/3500:512:256:soft:256 bush:foot:1.9:e1.6/6000:512:256:soft:256 \
 house:foot:4.6:e1.6/10000:1024:512:hard:256 lamp:height:2.7:e1.6:512:256:hard:256 \
 barrels:foot:1.9:e1.6/5000:512:256:hard:256 crystals:height:1.7:e1.6:512:256:hard:256 fence:foot:2.8:e1.6:512:256:hard:256 \
 bridge:foot:8.0:e1.6:1024:512:hard:256 flowers:foot:1.3:e1.6/5000:512:256:soft:256 \
 2>&1 | grep -E "^(DONE)|Traceback|Error"
# a capped prop can come out the same for phones; keep only the copies that differ
for g in "$MOB"/*.glb; do cmp -s "$g" "$OUT/models/$(basename "$g")" && rm "$g"; done
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
mc 256 $C/ogre.glb 1024 run=$D3/ogre_run.glb attack=$D3/ogre_attack.glb death=$D3/ogre_death.glb roar=$D3/ogre_roar.glb taunt=$RAW/varco/anim_v6/ogre_taunt.glb
mc 512 $C/sera.glb 1024 idle=$D3/sera_idle.glb run=$D3/sera_run.glb attack=$D3/sera_attack.glb skill=$D3/sera_skill.glb death=$D3/sera_death.glb cheer=$D3/sera_cheer.glb hit=$A5/sera_hit.glb
mc 256 $C/skeleton_knight.glb 1024 run=$A4/skeleton_knight_run.glb attack=$A4/skeleton_knight_attack.glb death=$A4/skeleton_knight_death.glb hit=$A5/skeleton_knight_hit.glb rise=$A5/skeleton_knight_rise_supine.glb
mc 512 $C/lich.glb 1024 run=$A4/lich_walk.glb attack=$A4/lich_attack.glb death=$A4/lich_death.glb roar=$A4/lich_summon.glb taunt=$A5/lich_taunt.glb cast=$A5/lich_cast.glb
mc 512 $C/ranger.glb 1024 idle=$D2/archer_anim_a.glb run=$RAW/varco/anim_v6/ranger_run.glb attack=$D2/archer_anim_b.glb skill=$RAW/varco/anim_v6/ranger_skill.glb death=$RAW/varco/anim_v6/ranger_death.glb cheer=$RAW/varco/anim_v6/ranger_cheer.glb hit=$RAW/varco/anim_v6/ranger_hit.glb
echo ALL_DONE
