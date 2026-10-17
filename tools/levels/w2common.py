"""Общее для генераторов уровней мира 2 «Мастерские» (tools/levels/w02_*.py).
Level — набор блоков, узлов и чекпоинтов; write() пишет сцену с задником зоны, ориентиром
и кладкой мастерских. Координаты — в тайлах."""
from pathlib import Path

T = 64
ROOT = Path(__file__).resolve().parents[2]

# Короткое имя → скрипт механизма (ext_resource id = короткое имя).
SCRIPTS = {
    'plate': 'res://src/mechanisms/pressure_plate.gd',
    'door': 'res://src/mechanisms/door.gd',
    'crate': 'res://src/mechanisms/crate.gd',
    'lever': 'res://src/mechanisms/lever.gd',
    'conveyor': 'res://src/mechanisms/conveyor.gd',
    'spring': 'res://src/mechanisms/spring_pad.gd',
    'brittle': 'res://src/mechanisms/brittle_floor.gd',
    'spinner': 'res://src/mechanisms/spinner.gd',
    'bellows': 'res://src/mechanisms/bellows.gd',
    'crane': 'res://src/mechanisms/crane.gd',
    'wire': 'res://src/mechanisms/wire.gd',
    'spark': 'res://src/mechanisms/spark.gd',
    'keg': 'res://src/mechanisms/keg.gd',
    'cracked': 'res://src/mechanisms/cracked_wall.gd',
    'beetle': 'res://src/mechanisms/beetle.gd',
    'spikes': 'res://src/mechanisms/spikes.gd',
    'saw': 'res://src/mechanisms/saw.gd',
    'press': 'res://src/mechanisms/press.gd',
    'hook': 'res://src/mechanisms/hook.gd',
    'ghost': 'res://src/mechanisms/ghost.gd',
    'crusher': 'res://src/mechanisms/crusher.gd',
    'finish': 'res://src/mechanisms/finish.gd',
    'mover': 'res://src/mechanisms/mover.gd',
    'wheel': 'res://src/mechanisms/wheel.gd',
    'lantern': 'res://src/mechanisms/lantern.gd',
    'turntable': 'res://src/mechanisms/turntable.gd',
    'big_machine': 'res://src/mechanisms/big_machine.gd',
    'fist': 'res://src/mechanisms/fist.gd',
    'machine_gate': 'res://src/mechanisms/machine_gate.gd',
    'clock': 'res://src/mechanisms/clock.gd',
    'darkness': 'res://src/level/darkness.gd',
    'hint': 'res://src/level/hint_sign.gd',
}
# Тип узла по скрипту.
KINDS = {
    'plate': 'AnimatableBody2D', 'door': 'AnimatableBody2D', 'crate': 'CharacterBody2D',
    'conveyor': 'StaticBody2D', 'spring': 'StaticBody2D', 'brittle': 'StaticBody2D',
    'spinner': 'AnimatableBody2D', 'cracked': 'StaticBody2D', 'beetle': 'CharacterBody2D',
    'press': 'AnimatableBody2D', 'mover': 'AnimatableBody2D', 'turntable': 'AnimatableBody2D', 'fist': 'AnimatableBody2D', 'machine_gate': 'Node', 'clock': 'Node',
}
LM_DIR = 'res://assets/backgrounds/world_02/source/'
HAZE = 'Color(0.860, 0.900, 0.960, 1)'
# Вертикальные ориентиры задания 17 (1024 × 1536) — выше по кадру.
TALL = {'w02_lm05_windmill_bellows.png', 'w02_lm06_switch_tower.png', 'w02_lm07_shift_bell.png',
        'w02_lm10_weighing_tower.png', 'w02_lm18_lightning_tower.png', 'w02_lm20_machine_core.png'}


def landmark_node(landmark, width):
    """Узел ориентира на заднике (строки сцены): горизонтальный — по умолчанию, высокий — выше."""
    tall = landmark in TALL
    return f'''
[node name="Landmark" type="Node2D" parent="Backdrop"]
script = ExtResource("bl")
texture = ExtResource("lm")
parallax = 0.3
parallax_y = 0.1
height = {0.72 if tall else 0.6}
center_y = {0.6 if tall else 0.55}
zoom_follow = 0.3
repeat = false
world_x = {round(width * T * 0.35)}.0
haze = 0.22
haze_color = {HAZE}
'''
COLORS = {
    'orange': 'Color(0.95, 0.6, 0.2, 1)', 'blue': 'Color(0.4, 0.7, 0.95, 1)',
    'green': 'Color(0.35, 0.8, 0.4, 1)', 'purple': 'Color(0.7, 0.45, 0.95, 1)',
    'red': 'Color(0.9, 0.3, 0.3, 1)', 'yellow': 'Color(0.95, 0.85, 0.3, 1)',
    'teal': 'Color(0.3, 0.8, 0.75, 1)', 'pink': 'Color(0.95, 0.5, 0.7, 1)',
}


def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'


def path(name):
    return f'NodePath("../{name}")'


def vec(x, y):
    return f'Vector2({x:g}, {y:g})'


def pts(*xy):
    """Точки провода в тайлах: pts((x, y), (x, y), ...)."""
    return 'PackedVector2Array(' + ', '.join(f'{x:g}, {y:g}' for x, y in xy) + ')'


def text(s):
    return '"' + s.replace('"', '\\"') + '"'


class Level:
    def __init__(self, name, title, width, zone='yard', landmark=None):
        self.name, self.title, self.width = name, title, width
        self.zone, self.landmark = zone, landmark
        self.blocks = [(0, -8, 1, 30), (width - 1, -8, 1, 30)]
        self.checkpoints = [(2, 12)]
        self.nodes = []
        self.used = set()
        self.kill_y = 19.0
        self.slot_spawns = []  # свои точки появления игроков (разведённые коридоры)
        self.bounds_h = 27

    def block(self, x, y, w, h):
        self.blocks.append((x, y, w, h))

    def node(self, name, script, x, y, kind=None, **props):
        self.used.add(script)
        kind = kind or KINDS.get(script, 'Node2D')
        lines = [f'[node name="{name}" type="{kind}" parent="."]']
        if x is not None:
            lines.append(f'position = Vector2({x * T:g}, {y * T:g})')
        lines.append(f'script = ExtResource("{script}")')
        lines += [f'{k} = {v}' for k, v in props.items()]
        self.nodes.append('\n'.join(lines) + '\n')

    def write(self, file_name):
        res = ['[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]',
               f'[ext_resource type="PackedScene" path="res://levels/backdrops/w02_{self.zone}.tscn" id="bd"]']
        if self.landmark:
            res.append('[ext_resource type="Script" path="res://src/level/backdrop_layer.gd" id="bl"]')
            res.append(f'[ext_resource type="Texture2D" path="{LM_DIR}{self.landmark}" id="lm"]')
        res += [f'[ext_resource type="Script" path="{SCRIPTS[s]}" id="{s}"]' for s in sorted(self.used)]
        blocks = ', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in self.blocks)
        cps = ', '.join(f'Vector2({x:g}, {y:g})' for x, y in self.checkpoints)
        head = '\n'.join(['[gd_scene format=3]', ''] + res + ['', f'[node name="{self.name}" type="Node2D"]',
            'script = ExtResource("1")', f'title = "{self.title}"', f'blocks = Array[Rect2]([{blocks}])',
            f'checkpoints = Array[Vector2]([{cps}])'] + ([
            'slot_spawns = Array[Vector2]([' + ', '.join(f'Vector2({x:g}, {y:g})' for x, y in self.slot_spawns) + '])']
            if self.slot_spawns else []) + [f'bounds_tiles = Rect2(0, -8, {self.width:g}, {self.bounds_h:g})',
            f'kill_y_tiles = {self.kill_y:g}', 'ground_fill = "w02_fill"', 'ground_deep = "w02_deep"',
            'ground_top = "w02_top"', 'ground_side = "w02_side"', ''])
        tail = '[node name="Backdrop" parent="." instance=ExtResource("bd")]\n'
        if self.landmark:
            tail += landmark_node(self.landmark, self.width)
        out = ROOT / 'levels' / file_name
        out.write_text(head + '\n' + '\n'.join(self.nodes) + '\n' + tail, encoding='utf-8')
        print('written', out)
