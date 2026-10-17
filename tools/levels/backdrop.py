"""Задник уровня мира 1 и ориентир на нём — для генераторов сцен (tools/levels/*.py).
resources(zone, landmark) — строки ext_resource; tail(...) — узлы Backdrop и Landmark в конце сцены.
Ориентиры — исходники из assets/backgrounds/world_01/v2/source (задания 08, 09, 15)."""

LM_DIR = 'res://assets/backgrounds/world_01/v2/source/'
# Цвет дымки ориентира — как у дальних слоёв зоны (без записи — дымка по умолчанию).
HAZE = {
    'canyon': 'Color(0.827, 0.882, 0.949, 1)',
    'shrine': 'Color(0.839, 0.851, 0.949, 1)',
    'viaduct': 'Color(0.953, 0.890, 0.800, 1)',
    'viaduct_sunset': 'Color(0.949, 0.824, 0.776, 1)',
}
# Текстуры платформ зоны (без записи — кладка по умолчанию, w01_stone_fill / w01_cliff_fill).
GROUND = {
    'canyon': {'ground_fill': 'w01_canyon_fill', 'ground_deep': 'w01_canyon_deep'},
    'river': {'ground_fill': 'w01_river_fill'},
    'shrine': {'ground_fill': 'w01_shrine_fill'},
    'viaduct': {'ground_fill': 'w01_viaduct_fill'},
    'viaduct_sunset': {'ground_fill': 'w01_viaduct_fill'},
}
# Вертикальные ориентиры (1024 × 1536) — выше и ниже по кадру.
TALL = {'w01_v2_lm13_lift_tower.png', 'w01_v2_lm15_bell_crypt.png', 'w01_v2_lm20_viaduct_keep.png',
        'w01_v2_lm23_landslide.png'}


def resources(zone, landmark=None):
    lines = [f'[ext_resource type="PackedScene" path="res://levels/backdrops/w01_{zone}.tscn" id="bd"]']
    if landmark:
        lines.append('[ext_resource type="Script" path="res://src/level/backdrop_layer.gd" id="bl"]')
        lines.append(f'[ext_resource type="Texture2D" path="{LM_DIR}{landmark}" id="lm"]')
    return '\n'.join(lines)


def ground(zone):
    """Свойства корня уровня: текстуры платформ зоны (строки сцены, каждая с переводом строки)."""
    return ''.join(f'{k} = "{v}"\n' for k, v in GROUND.get(zone, {}).items())


def tail(zone, landmark=None, level_width_tiles=60.0):
    out = '[node name="Backdrop" parent="." instance=ExtResource("bd")]\n'
    if not landmark:
        return out
    tall = landmark in TALL
    out += f'''
[node name="Landmark" type="Node2D" parent="Backdrop"]
script = ExtResource("bl")
texture = ExtResource("lm")
parallax = 0.3
parallax_y = 0.1
height = {0.62 if tall else 0.5}
center_y = {0.6 if tall else 0.46}
zoom_follow = 0.3
repeat = false
world_x = {round(level_width_tiles * 64 * 0.35)}.0
haze = 0.3
'''
    if zone in HAZE:
        out += f'haze_color = {HAZE[zone]}\n'
    return out
