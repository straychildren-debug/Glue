"""Игровые спрайты механизмов v2 из картинок генератора (задание docs/12).

Запуск (нужен Python 3 с Pillow):
    python tools/make_props.py

Исходники — assets/props/v2/source/ (не меняются), результат — assets/props/v2/ под именами,
которые ждёт игра (src/game/art.gd: v2 заменяет v1 по одному спрайту).
Масштаб как у v1: 1 тайл = 64 px игры = 256 px текстуры (4 px текстуры на 1 px игры).

Каждый спрайт — кусок исходника (рамка в px исходника), уменьшенный в `scale` раз
(px текстуры на px исходника) и положенный на холст так, что точка привязки исходника
попадает в точку привязки холста. Для кусков длинных предметов (торец и повторяющаяся
середина) холст — ровно уменьшенный кусок. Места разреза выбраны по рисунку: середина
моста — от оси одной железной скобы до оси следующей, шипов и зубьев пресса — от впадины
до впадины через два зуба, так что при повторе стыка не видно.
Уменьшение — в премультиплицированном цвете (без тёмной каймы по краю прозрачности).
"""

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets", "props", "v2", "source")
OUT = os.path.join(ROOT, "assets", "props", "v2")


def piece(name, file, box, scale, canvas=None, anchor_src=None, anchor_canvas=(0, 0)):
    """Запись таблицы: canvas None — холст по размеру куска; anchor_src None — левый верх куска."""
    return name, file, box, scale, canvas, anchor_src, anchor_canvas


def fit(name, file, box, canvas, margin=3):
    """Цельный предмет: вписать рамку в холст с запасом, по центру, низом на запас от низа."""
    w, h = box[2] - box[0], box[3] - box[1]
    scale = min((canvas[0] - 2 * margin) / w, (canvas[1] - 2 * margin) / h)
    bottom_center = ((box[0] + box[2]) / 2.0, box[3])
    return piece(name, file, box, scale, canvas, bottom_center, (canvas[0] / 2.0, canvas[1] - margin))


# --- Двери, мосты, балки -------------------------------------------------------------------
DOOR_S = 254 / 419           # створка 419 px исходника → 254 px текстуры (1 тайл с контуром)
BRIDGE_S = 128 / 150         # настил толщиной 150 px → полтайла
BEAM_S = 64 / 74             # брус толщиной 74 px → четверть тайла
# Плиты: высота плиты с крышкой 103 px → 80 px текстуры (20 px игры, низ утоплен на 4 px).
PLATE_S = 80 / 103
PLATE_STATES = {  # имя → левый край состояния; низ у всех — строка 406
    "plate_off": 47, "plate_on": 571, "latch_off": 1098, "latch_on": 1625}
SPIKES_S = 144 / 259         # шипы 259 px → 36 px игры
TEETH_S = 104 / 206          # зубья пресса 206 px → 26 px игры
RAIL_S = 40 / 67             # рельс пилы 67 px → 10 px игры

SPRITES = [
    fit("crate", "p01_crate.png", (109, 121, 1145, 1133), (256, 256)),
    fit("crate_heavy", "p02_crate_heavy.png", (144, 176, 1110, 1079), (256, 256)),
    # Дверь: торец — верх створки с верхней полосой; середина — тайл вокруг средней полосы.
    piece("door_end", "p03_door.png", (234, 106, 653, 345), DOOR_S, (256, 145), (234, 106), (1, 0)),
    piece("door_mid", "p03_door.png", (234, 678, 653, 1100), DOOR_S, (256, 256), (234, 678), (1, 0)),
    piece("bridge_end", "p04_bridge.png", (34, 285, 300, 435), BRIDGE_S),
    piece("bridge_mid", "p04_bridge.png", (785, 285, 1386, 435), BRIDGE_S),
    piece("beam_end", "p05_beam.png", (60, 322, 250, 396), BEAM_S),
    piece("beam_mid", "p05_beam.png", (600, 322, 1500, 396), BEAM_S),
    piece("spikes_end", "p09_spikes.png", (54, 307, 273, 566), SPIKES_S),
    piece("spikes_mid", "p09_spikes.png", (273, 307, 553, 566), SPIKES_S),
    piece("press_teeth_end", "p16_press.png", (58, 266, 238, 472), TEETH_S),
    piece("press_teeth_mid", "p16_press.png", (238, 266, 573, 472), TEETH_S),
    piece("saw_rail_end", "p15_saw.png", (703, 561, 790, 628), RAIL_S),
    piece("saw_rail_mid", "p15_saw.png", (1000, 561, 1600, 628), RAIL_S),
    # Диск пилы: 540 px → 76 px игры (радиус 35 и зубья с контуром).
    fit("saw_blade", "p15_saw.png", (112, 104, 652, 634), (304, 304), 0),
    # Флажок 64 × 104 игры: древко — 12 px от левого края (каменная пятка шире древка), низ — пол.
    piece("flag_off", "p07_flags.png", (213, 61, 734, 968), 416 / 907, (256, 416), (313, 968), (48, 416)),
    piece("flag_on", "p07_flags.png", (837, 57, 1351, 968), 416 / 907, (256, 416), (937, 968), (48, 416)),
    # Козлы качелей: одна рамка на оба состояния, ось — (679, 180) и (1492, 180).
    piece("seesaw_base", "p08_seesaw.png", (323, 66, 1036, 662), 384 / 713, (384, 321), (679.5, 180), (192, 61)),
    piece("seesaw_base_locked", "p08_seesaw.png", (1136, 66, 1849, 662), 384 / 713, (384, 321), (1492.5, 180), (192, 61)),
    # Призрак ≈ 90 px игры; привязка — середина головы.
    piece("ghost_chase", "p10_ghost.png", (72, 184, 661, 634), 0.6, (448, 288), (425, 400), (224, 144)),
    piece("ghost_shy", "p10_ghost.png", (750, 180, 1295, 637), 0.6, (448, 288), (1075, 400), (224, 144)),
    piece("ghost_calm", "p10_ghost.png", (1422, 178, 1941, 635), 0.6, (448, 288), (1720, 400), (224, 144)),
    # Крюк: привязка — середина зева, за который хватаются.
    piece("hook", "p11_hook.png", (184, 352, 886, 1275), 0.195, (160, 192), (505, 1080), (80, 140)),
    # Ключ — по центру; замок: оба состояния по левому краю и низу (низ — 24 px игры под точкой).
    piece("key", "p12_key_lock.png", (75, 404, 720, 718), 0.25, (176, 96), (397, 561), (88, 48)),
    piece("lock_closed", "p12_key_lock.png", (781, 263, 1195, 718), 0.387, (184, 224), (781, 718), (8, 216)),
    piece("lock_open", "p12_key_lock.png", (1288, 168, 1742, 719), 0.387, (184, 224), (1288, 719), (8, 216)),
    # Рычаг: оба состояния по середине и низу каменного основания.
    piece("lever_off", "p13_lever.png", (46, 215, 559, 593), 0.3, (320, 128), (394, 593), (160, 124)),
    piece("lever_on", "p13_lever.png", (669, 209, 1168, 593), 0.3, (320, 128), (826, 593), (160, 124)),
    # Подъёмник: колесо блока (центр 967, 479) и подвес площадки.
    piece("lift_wheel", "p14_lift.png", (722, 234, 1213, 725), 0.26, (128, 128), (967, 479), (64, 64)),
    piece("lift_hanger", "p14_lift.png", (1373, 374, 1668, 719), 0.26, (80, 96), (1520, 719), (40, 92)),
    # Ворота финиша P17 (задание 15): 104 × 144 игры, дверь чуть выше игрока; закрыты / открыты.
    fit("finish_closed", "p17_finish.png", (207, 166, 707, 868), (416, 576)),
    fit("finish_open", "p17_finish.png", (800, 166, 1295, 868), (416, 576)),
    # Табличка-подсказка P19: 66 × 104 игры; середина доски — 71 px над полом.
    fit("hint_sign", "p19_hint_sign.png", (209, 335, 794, 1251), (264, 416)),
    # Батут P20 со скатами: ширина 170 игры, низ — строка 504; свободный и сжатый.
    piece("spring_pad", "p20_spring_pad.png", (49, 373, 1039, 504), 0.68, (680, 96), (544, 504), (340, 93)),
    piece("spring_pad_down", "p20_spring_pad.png", (1130, 418, 2124, 504), 0.68, (680, 96), (1627, 504), (340, 93)),
    # Обвал P18: полоса камней с шипами вправо, концы оформлены; игра кладёт копии одну под другой,
    # каждую вторую — отражённой по вертикали (стык к стыку без шва). Кончики шипов — правый край.
    piece("rockfall", "p18_rockfall.png", (190, 79, 603, 1903), 0.5),
]
# --- Мир 2 «Мастерские»: листы-модели задания 11 (docs/референсы), фон вырезан по цвету в
# assets/props/v2/source/w2. Рамки и масштабы подобраны по рисунку; размеры в игре — в комментариях.
SPRITES += [
]

# --- Мир 2, задание 17: спрайты механизмов вместо вырезок из листов (масштаб 1 — как в исходнике;
# в игре рисуются по размеру механизма).
SPRITES += [
    # P21: лента — торец с барабаном и скобой, середина — период планок (174 px), высота 122 → 24 игры.
    piece("w2_belt_end", "p21_conveyor.png", (27, 346, 258, 468), 1.0),
    piece("w2_belt_mid", "p21_conveyor.png", (402, 346, 576, 468), 1.0),
    # P26: провод — период от середины до середины между изоляторами (изолятор в центре), ось
    # провода — строка 398; коробка развилки (стрелка влево / вправо), клемма, кол заземления.
    piece("w2_wire_mid", "p26_wires.png", (181, 352, 384, 444), 1.0),
    piece("w2_wire_box_left", "p26_wires.png", (1008, 221, 1302, 479), 1.0),
    piece("w2_wire_box_right", "p26_wires.png", (1340, 221, 1635, 479), 1.0),
    piece("w2_wire_end", "p26_wires.png", (1694, 350, 1890, 460), 1.0),
    piece("w2_wire_ground", "p26_wires.png", (1945, 352, 2117, 606), 1.0),
    # P27: бочонок (тело 390 px → 42 игры, 4 px текстуры на px игры), обычный и с горящим фитилём;
    # общий холст, низ тела — низ холста, середина тела — середина холста.
    piece("w2_keg", "p27_keg.png", (422, 280, 812, 758), 0.43, (180, 240), (617, 758), (90, 239)),
    piece("w2_keg_lit", "p27_keg.png", (963, 208, 1355, 758), 0.43, (180, 240), (1158, 758), (90, 239)),
    # P29: искра бежит вправо (пламя хвостом влево); середина огонька — (641, 402) исходника.
    piece("w2_spark", "p29_spark.png", (229, 221, 726, 569), 0.67),
    # P30: жук вправо — два шага и толчок; общий холст, низ лап — низ холста, середина — середина.
    piece("w2_beetle", "p30_beetle.png", (75, 186, 716, 544), 0.5, (340, 184), (395, 544), (170, 183)),
    piece("w2_beetle_2", "p30_beetle.png", (788, 186, 1391, 553), 0.5, (340, 184), (1089, 553), (170, 183)),
    piece("w2_beetle_push", "p30_beetle.png", (1439, 216, 2100, 550), 0.5, (340, 184), (1769, 550), (170, 183)),
    # P22: балка — торец с накладкой, середина — период заклёпок (217 px); ступица отдельно.
    piece("w2_beam_end", "p22_rotating_beam.png", (54, 294, 132, 429), 1.0),
    piece("w2_beam_mid", "p22_rotating_beam.png", (402, 294, 619, 429), 1.0),
    piece("w2_hub", "p22_rotating_beam.png", (1961, 271, 2141, 453), 1.0),
    # P23: настил — торец с верёвкой и гвоздём, середина — доска (100 px); треснувший целиком.
    piece("w2_plank_end", "p23_brittle_floor.png", (27, 343, 141, 411), 1.0),
    piece("w2_plank_mid", "p23_brittle_floor.png", (233, 343, 337, 411), 1.0),
    piece("w2_plank_cracked", "p23_brittle_floor.png", (616, 344, 1142, 425), 1.0),
    # P24: мехи — раскрытые и сжатые; общий холст по стойке (низ-лево), сопло раскрытых — (790, 400).
    piece("w2_bellows", "p24_bellows.png", (146, 112, 807, 856), 0.62, (420, 466), (146, 856), (2, 464)),
    piece("w2_bellows_blow", "p24_bellows.png", (957, 201, 1574, 855), 0.62, (420, 466), (957, 855), (2, 464)),
    # P25: рельс — торец с упором, середина — период накладок (177 px); тележка; тяга (стержень).
    piece("w2_rail_end", "p25_crane.png", (28, 460, 168, 587), 1.0),
    piece("w2_rail_mid", "p25_crane.png", (393, 460, 570, 587), 1.0),
    piece("w2_trolley", "p25_crane.png", (1213, 434, 1595, 607), 1.0),
    piece("w2_rod", "p25_crane.png", (1650, 362, 1690, 520), 1.0),
    # P31: ворота мастерских — как P17 (холст 416 × 576), закрыты / открыты.
    fit("finish_w2_closed", "p31_finish_workshop.png", (205, 150, 716, 857), (416, 576)),
    fit("finish_w2_open", "p31_finish_workshop.png", (810, 150, 1323, 857), (416, 576)),
    # P28: треснувшая стена (колонна целиком), пролёт-мост (торец и повторяемая середина), шесть обломков.
    piece("w2_wall", "p28_cracked.png", (82, 111, 299, 585), 1.0),
    piece("w2_slab_end", "p28_cracked.png", (348, 446, 438, 585), 1.0),
    piece("w2_slab_mid", "p28_cracked.png", (438, 446, 1102, 585), 1.0),
    piece("w2_chunk_1", "p28_cracked.png", (1375, 459, 1498, 585), 1.0),
    piece("w2_chunk_2", "p28_cracked.png", (1513, 509, 1610, 584), 1.0),
    piece("w2_chunk_3", "p28_cracked.png", (1629, 479, 1761, 584), 1.0),
    piece("w2_chunk_4", "p28_cracked.png", (1785, 486, 1888, 584), 1.0),
    piece("w2_chunk_5", "p28_cracked.png", (1910, 491, 1988, 572), 1.0),
    piece("w2_chunk_6", "p28_cracked.png", (2010, 509, 2106, 585), 1.0),
]

for name, left in PLATE_STATES.items():
    kind, state = name.split("_")
    # Торец — скос и начало крышки, середина — ровная крышка; холст 80 px высотой, низ — строка 406.
    SPRITES.append(piece(f"{kind}_end_{state}", "p06_plates.png", (left, 303, left + 110, 406), PLATE_S))
    SPRITES.append(piece(f"{kind}_mid_{state}", "p06_plates.png", (left + 150, 303, left + 350, 406), PLATE_S))


REFS = os.path.join(ROOT, "docs", "референсы")


def key_sheet(file: str) -> None:
    """Лист-модель мира 2+ (docs/референсы/…) без фона: фон ровный светлый — цвет углов;
    прозрачность растёт с отличием от него, цвет края очищается от примеси фона."""
    import numpy as np
    name = os.path.basename(file)
    folder = "enemies" if name.startswith("enemy_") else "mechanisms"
    a = np.asarray(Image.open(os.path.join(REFS, folder, name)).convert("RGB")).astype(np.float32)
    bg = np.median(np.array([a[5, 5], a[5, -5], a[-5, 5], a[-5, -5]]), axis=0)
    alpha = np.clip((np.abs(a - bg).sum(axis=2) - 14.0) / 26.0, 0.0, 1.0)[..., None]
    rgb = np.where(alpha > 0.01, (a - bg * (1.0 - alpha)) / np.maximum(alpha, 0.01), a)
    out = np.dstack([np.clip(rgb, 0, 255), alpha[..., 0] * 255]).astype(np.uint8)
    os.makedirs(os.path.join(SRC, "w2"), exist_ok=True)
    Image.fromarray(out, "RGBA").save(os.path.join(SRC, file))


def load(file: str) -> Image.Image:
    if file.startswith("w2/") and not os.path.exists(os.path.join(SRC, file)):
        key_sheet(file)
    image = Image.open(os.path.join(SRC, file)).convert("RGBA")
    if file == "p07_flags.png":  # генератор дал сплошной пурпурный фон вместо прозрачности
        pixels = image.load()
        for y in range(image.height):
            for x in range(image.width):
                r, g, b, _ = pixels[x, y]
                if r > 200 and g < 90 and b > 200:
                    pixels[x, y] = (0, 0, 0, 0)
    return image


def main() -> None:
    cache = {}
    for name, file, box, scale, canvas, anchor_src, anchor_canvas in SPRITES:
        if file not in cache:
            if not os.path.exists(os.path.join(SRC, file)) and not file.startswith("w2/"):
                print("нет исходника", file)
                continue
            cache[file] = load(file)
        cut = cache[file].crop(box).convert("RGBa")  # премультиплицированный цвет
        size = (max(1, round(cut.width * scale)), max(1, round(cut.height * scale)))
        cut = cut.resize(size, Image.LANCZOS).convert("RGBA")
        if canvas is None:
            cut.save(os.path.join(OUT, name + ".png"))
            print("PROP", name, size)
            continue
        if anchor_src is None:
            anchor_src = box[:2]
        x = round(anchor_canvas[0] - (anchor_src[0] - box[0]) * scale)
        y = round(anchor_canvas[1] - (anchor_src[1] - box[1]) * scale)
        result = Image.new("RGBA", canvas, (0, 0, 0, 0))
        result.alpha_composite(cut, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
        result.save(os.path.join(OUT, name + ".png"))
        print("PROP", name, size, "->", canvas, "at", (x, y))


if __name__ == "__main__":
    main()
