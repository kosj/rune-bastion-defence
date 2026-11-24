Phone-only replacements, swapped into the mobile data pack by `tools/build_web.sh`
(`.gdignore` keeps Godot from importing them into the desktop build).

- `models/`: towers, castle and portal rebuilt by `tools/pipeline/process_hq.py` at roughly 35-45%
  of the desktop triangle budget, with normal maps re-baked for the lighter meshes
  (`tools/pipeline/rebuild_assets.sh` has the exact budgets).
