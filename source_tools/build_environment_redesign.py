"""Adapt the new Meshy foliage/lantern and make a reusable beveled paving stone."""
import bpy
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import build_meshy_environment as pipeline

ROOT = Path(pipeline.ROOT)
pipeline.SOURCE = str(ROOT / 'source_assets/environment_redesign')
specs = {
    'fern': {'target': 'fern', 'height': 0.55, 'sink': 0.015},
    'lantern': {'target': 'sanctuary_lantern', 'height': 1.1, 'sink': 0.0},
}
metrics = {name: pipeline.build(name, spec) for name, spec in specs.items()}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add(size=1)
tile = bpy.context.object
tile.name = 'RoundedFlagstone'
tile.dimensions = (2, 2, 0.08)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bevel = tile.modifiers.new('WornEdges', 'BEVEL')
bevel.width = 0.025
bevel.segments = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'godot/assets/environment/flagstone_beveled.glb'),
    export_format='GLB', use_selection=True, export_animations=False)
(ROOT / 'blender/environment_redesign_metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf-8')
