#!/usr/bin/env python3
"""
Convert GGG's poe2-skilltree-export data.json to PoB's tree.json and tree.lua format.

Reads the raw 0.5.0 data.json from Grinding Gear Games and produces:
  - TreeData/0_5/tree.json (JSON format)
  - TreeData/0_5/tree.lua (Lua table format)
"""

import json
import math
import os
import sys
import copy

# ──────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
TREEDATA_DIR = os.path.join(REPO_ROOT, "src", "TreeData")

OLD_TREE_JSON = os.path.join(TREEDATA_DIR, "0_4", "tree.json")
INPUT_DATA_JSON = "/tmp/opencode/poe2_tree_0.5.0.json"
OUTPUT_DIR = os.path.join(TREEDATA_DIR, "0_5")
OUTPUT_TREE_JSON = os.path.join(OUTPUT_DIR, "tree.json")
OUTPUT_TREE_LUA = os.path.join(OUTPUT_DIR, "tree.lua")

# ──────────────────────────────────────────────
# Class mapping from 0.5 index → PoB's expected fields
# PoB expects: integerId, name, base_str, base_dex, base_int, ascendancies, background
# ──────────────────────────────────────────────

CLASS_ATTRS = {
    # name: (str, dex, int)
    "Marauder": (20, 7, 7),
    "Witch": (7, 7, 20),
    "Ranger": (7, 20, 7),
    "Duelist": (16, 11, 7),
    "Shadow": (7, 16, 11),
    "Templar": (11, 7, 16),
    "Warrior": (20, 7, 7),
    "Sorceress": (7, 7, 20),
    "Huntress": (7, 20, 7),
    "Mercenary": (11, 11, 11),
    "Monk": (7, 11, 16),
    "Druid": (11, 7, 16),
}

CLASS_INTEGER_IDS = {
    "Marauder": 0,
    "Witch": 1,
    "Ranger": 2,
    "Duelist": 3,
    "Shadow": 4,
    "Templar": 5,
    "Warrior": 6,
    "Sorceress": 7,
    "Huntress": 8,
    "Mercenary": 9,
    "Monk": 10,
    "Druid": 11,
}

def generate_class_background(cls_name):
    """Generate class background dict from class name."""
    return {
        "active": {"height": 2000, "width": 2000},
        "bg": {"height": 2000, "width": 2000},
        "height": 1500,
        "image": f"Classes{cls_name}",
        "section": "AscendancyBackground",
        "width": 1500,
        "x": 0,
        "y": 0,
    }


def generate_ascendancy_background(asc_name, offset_x, offset_y):
    """Generate ascendancy background dict from name and offsets."""
    return {
        "height": 1500,
        "image": f"Classes{asc_name}",
        "section": "AscendancyBackground",
        "width": 1500,
        "x": offset_x if offset_x else 0,
        "y": offset_y if offset_y else 0,
    }


def get_class_image_name(cls_name):
    """Map from 0.5 class name to the image identifier used in ddsCoords."""
    return f"Classes{cls_name}"


def get_ascendancy_image_name(asc_name):
    """Map ascendancy name to image identifier."""
    return f"Classes{asc_name}"


# ──────────────────────────────────────────────
# Static metadata from 0_4 (does not change between versions)
# ──────────────────────────────────────────────

ASSETS = {
    "CharacterAscendancyLineConnectorActive": ["CharacterAscendancy_orbit_intermediateactive0.png"],
    "CharacterAscendancyLineConnectorIntermediate": ["CharacterAscendancy_orbit_intermediate0.png"],
    "CharacterAscendancyLineConnectorNormal": ["CharacterAscendancy_orbit_normal0.png"],
    "CharacterAscendancyOrbit1Active": ["CharacterAscendancy_orbit_intermediateactive9.png"],
    "CharacterAscendancyOrbit1Intermediate": ["CharacterAscendancy_orbit_intermediate9.png"],
    "CharacterAscendancyOrbit1Normal": ["CharacterAscendancy_orbit_normal9.png"],
    "CharacterAscendancyOrbit2Active": ["CharacterAscendancy_orbit_intermediateactive8.png"],
    "CharacterAscendancyOrbit2Intermediate": ["CharacterAscendancy_orbit_intermediate8.png"],
    "CharacterAscendancyOrbit2Normal": ["CharacterAscendancy_orbit_normal8.png"],
    "CharacterAscendancyOrbit3Active": ["CharacterAscendancy_orbit_intermediateactive6.png"],
    "CharacterAscendancyOrbit3Intermediate": ["CharacterAscendancy_orbit_intermediate6.png"],
    "CharacterAscendancyOrbit3Normal": ["CharacterAscendancy_orbit_normal6.png"],
    "CharacterAscendancyOrbit4Active": ["CharacterAscendancy_orbit_intermediateactive5.png"],
    "CharacterAscendancyOrbit4Intermediate": ["CharacterAscendancy_orbit_intermediate5.png"],
    "CharacterAscendancyOrbit4Normal": ["CharacterAscendancy_orbit_normal5.png"],
    "CharacterAscendancyOrbit5Active": ["CharacterAscendancy_orbit_intermediateactive4.png"],
    "CharacterAscendancyOrbit5Intermediate": ["CharacterAscendancy_orbit_intermediate4.png"],
    "CharacterAscendancyOrbit5Normal": ["CharacterAscendancy_orbit_normal4.png"],
    "CharacterAscendancyOrbit6Active": ["CharacterAscendancy_orbit_intermediateactive3.png"],
    "CharacterAscendancyOrbit6Intermediate": ["CharacterAscendancy_orbit_intermediate3.png"],
    "CharacterAscendancyOrbit6Normal": ["CharacterAscendancy_orbit_normal3.png"],
    "CharacterAscendancyOrbit7Active": ["CharacterAscendancy_orbit_intermediateactive7.png"],
    "CharacterAscendancyOrbit7Intermediate": ["CharacterAscendancy_orbit_intermediate7.png"],
    "CharacterAscendancyOrbit7Normal": ["CharacterAscendancy_orbit_normal7.png"],
    "CharacterAscendancyOrbit8Active": ["CharacterAscendancy_orbit_intermediateactive2.png"],
    "CharacterAscendancyOrbit8Intermediate": ["CharacterAscendancy_orbit_intermediate2.png"],
    "CharacterAscendancyOrbit8Normal": ["CharacterAscendancy_orbit_normal2.png"],
    "CharacterAscendancyOrbit9Active": ["CharacterAscendancy_orbit_intermediateactive1.png"],
    "CharacterAscendancyOrbit9Intermediate": ["CharacterAscendancy_orbit_intermediate1.png"],
    "CharacterAscendancyOrbit9Normal": ["CharacterAscendancy_orbit_normal1.png"],
    "CharacterLineConnectorActive": ["Character_orbit_intermediateactive0.png"],
    "CharacterLineConnectorIntermediate": ["Character_orbit_intermediate0.png"],
    "CharacterLineConnectorNormal": ["Character_orbit_normal0.png"],
    "CharacterOrbit1Active": ["Character_orbit_intermediateactive9.png"],
    "CharacterOrbit1Intermediate": ["Character_orbit_intermediate9.png"],
    "CharacterOrbit1Normal": ["Character_orbit_normal9.png"],
    "CharacterOrbit2Active": ["Character_orbit_intermediateactive8.png"],
    "CharacterOrbit2Intermediate": ["Character_orbit_intermediate8.png"],
    "CharacterOrbit2Normal": ["Character_orbit_normal8.png"],
    "CharacterOrbit3Active": ["Character_orbit_intermediateactive6.png"],
    "CharacterOrbit3Intermediate": ["Character_orbit_intermediate6.png"],
    "CharacterOrbit3Normal": ["Character_orbit_normal6.png"],
    "CharacterOrbit4Active": ["Character_orbit_intermediateactive5.png"],
    "CharacterOrbit4Intermediate": ["Character_orbit_intermediate5.png"],
    "CharacterOrbit4Normal": ["Character_orbit_normal5.png"],
    "CharacterOrbit5Active": ["Character_orbit_intermediateactive4.png"],
    "CharacterOrbit5Intermediate": ["Character_orbit_intermediate4.png"],
    "CharacterOrbit5Normal": ["Character_orbit_normal4.png"],
    "CharacterOrbit6Active": ["Character_orbit_intermediateactive3.png"],
    "CharacterOrbit6Intermediate": ["Character_orbit_intermediate3.png"],
    "CharacterOrbit6Normal": ["Character_orbit_normal3.png"],
    "CharacterOrbit7Active": ["Character_orbit_intermediateactive7.png"],
    "CharacterOrbit7Intermediate": ["Character_orbit_intermediate7.png"],
    "CharacterOrbit7Normal": ["Character_orbit_normal7.png"],
    "CharacterOrbit8Active": ["Character_orbit_intermediateactive2.png"],
    "CharacterOrbit8Intermediate": ["Character_orbit_intermediate2.png"],
    "CharacterOrbit8Normal": ["Character_orbit_normal2.png"],
    "CharacterOrbit9Active": ["Character_orbit_intermediateactive1.png"],
    "CharacterOrbit9Intermediate": ["Character_orbit_intermediate1.png"],
    "CharacterOrbit9Normal": ["Character_orbit_normal1.png"],
    "CharacterPlannedLineConnectorActive": ["CharacterPlanned_orbit_intermediateactive0.png"],
    "CharacterPlannedLineConnectorIntermediate": ["CharacterPlanned_orbit_intermediate0.png"],
    "CharacterPlannedLineConnectorNormal": ["CharacterPlanned_orbit_normal0.png"],
    "CharacterPlannedOrbit1Active": ["CharacterPlanned_orbit_intermediateactive9.png"],
    "CharacterPlannedOrbit1Intermediate": ["CharacterPlanned_orbit_intermediate9.png"],
    "CharacterPlannedOrbit1Normal": ["CharacterPlanned_orbit_normal9.png"],
    "CharacterPlannedOrbit2Active": ["CharacterPlanned_orbit_intermediateactive8.png"],
    "CharacterPlannedOrbit2Intermediate": ["CharacterPlanned_orbit_intermediate8.png"],
    "CharacterPlannedOrbit2Normal": ["CharacterPlanned_orbit_normal8.png"],
    "CharacterPlannedOrbit3Active": ["CharacterPlanned_orbit_intermediateactive6.png"],
    "CharacterPlannedOrbit3Intermediate": ["CharacterPlanned_orbit_intermediate6.png"],
    "CharacterPlannedOrbit3Normal": ["CharacterPlanned_orbit_normal6.png"],
    "CharacterPlannedOrbit4Active": ["CharacterPlanned_orbit_intermediateactive5.png"],
    "CharacterPlannedOrbit4Intermediate": ["CharacterPlanned_orbit_intermediate5.png"],
    "CharacterPlannedOrbit4Normal": ["CharacterPlanned_orbit_normal4.png"],
    "CharacterPlannedOrbit5Active": ["CharacterPlanned_orbit_intermediateactive4.png"],
    "CharacterPlannedOrbit5Intermediate": ["CharacterPlanned_orbit_intermediate4.png"],
    "CharacterPlannedOrbit5Normal": ["CharacterPlanned_orbit_normal4.png"],
    "CharacterPlannedOrbit6Active": ["CharacterPlanned_orbit_intermediateactive3.png"],
    "CharacterPlannedOrbit6Intermediate": ["CharacterPlanned_orbit_intermediate3.png"],
    "CharacterPlannedOrbit6Normal": ["CharacterPlanned_orbit_normal3.png"],
    "CharacterPlannedOrbit7Active": ["CharacterPlanned_orbit_intermediateactive7.png"],
    "CharacterPlannedOrbit7Intermediate": ["CharacterPlanned_orbit_intermediate7.png"],
    "CharacterPlannedOrbit7Normal": ["CharacterPlanned_orbit_normal7.png"],
    "CharacterPlannedOrbit8Active": ["CharacterPlanned_orbit_intermediateactive2.png"],
    "CharacterPlannedOrbit8Intermediate": ["CharacterPlanned_orbit_intermediate2.png"],
    "CharacterPlannedOrbit8Normal": ["CharacterPlanned_orbit_normal2.png"],
    "CharacterPlannedOrbit9Active": ["CharacterPlanned_orbit_intermediateactive1.png"],
    "CharacterPlannedOrbit9Intermediate": ["CharacterPlanned_orbit_intermediate1.png"],
    "CharacterPlannedOrbit9Normal": ["CharacterPlanned_orbit_normal1.png"],
}

CONSTANTS = {
    "PSSCentreInnerRadius": 130,
    "characterAttributes": {
        "Dexterity": 1,
        "Intelligence": 2,
        "Strength": 0,
    },
    "classes": {
        "DexClass": 2,
        "DexIntClass": 6,
        "IntClass": 3,
        "StrClass": 1,
        "StrDexClass": 4,
        "StrDexIntClass": 0,
        "StrIntClass": 5,
    },
    "orbitAnglesByOrbit": [
        [0.0, 6.283185307179586],
        [0.0, 0.5235987755982988, 1.0471975511965976, 1.5707963267948966, 2.0943951023931953, 2.6179938779914944, 3.141592653589793, 3.6651914291880923, 4.1887902047863905, 4.71238898038469, 5.235987755982989, 5.497787143782138, 6.283185307179586],
        [0.0, 0.2617993877991494, 0.5235987755982988, 0.7853981633974483, 1.0471975511965976, 1.3089969389957472, 1.5707963267948966, 1.832595714594046, 2.0943951023931953, 2.356194490192345, 2.6179938779914944, 2.879793265829644, 3.141592653589793, 3.4033920413889422, 3.6651914291880923, 3.9269908169872415, 4.1887902047863905, 4.45058959258554, 4.71238898038469, 4.974188368183839, 5.235987755982989, 5.497787143782138, 5.759586531581297, 6.021385919380437, 6.283185307179586],
        [0.0, 0.2617993877991494, 0.5235987755982988, 0.7853981633974483, 1.0471975511965976, 1.3089969389957472, 1.5707963267948966, 1.832595714594046, 2.0943951023931953, 2.356194490192345, 2.6179938779914944, 2.879793265829644, 3.141592653589793, 3.4033920413889422, 3.6651914291880923, 3.9269908169872415, 4.1887902047863905, 4.45058959258554, 4.71238898038469, 4.974188368183839, 5.235987755982989, 5.497787143782138, 5.759586531581297, 6.021385919380437, 6.283185307179586],
        [0.0, 0.08726646259971647, 0.17453292519943295, 0.2617993877991494, 0.3490658503988659, 0.4363323129985824, 0.5235987755982988, 0.6108652381980153, 0.6981317007977318, 0.7853981633974483, 0.8726646259971648, 0.9599310885968813, 1.0471975511965976, 1.1344640137963142, 1.2217304763960306, 1.3089969389957472, 1.3962634015954636, 1.4835298641951802, 1.5707963267948966, 1.658062789394613, 1.7453292519943295, 1.832595714594046, 1.9198621771937625, 2.007128639793479, 2.0943951023931953, 2.1816615649929116, 2.2689280275926285, 2.356194490192345, 2.443460952792061, 2.5307274153917776, 2.6179938779914944, 2.705260340591211, 2.7925268031909273, 2.879793265829644, 2.9670597284293603, 3.0543261910290767, 3.141592653589793, 3.2288591161895095, 3.316125578789226, 3.4033920413889422, 3.490658503988659, 3.5779249665883754, 3.6651914291880923, 3.7524578917878086, 3.839724354387525, 3.9269908169872415, 4.014257279586958, 4.101523742186674, 4.1887902047863905, 4.276056667386107, 4.363323129985824, 4.45058959258554, 4.537856055185257, 4.625122517784973, 4.71238898038469, 4.799655442984406, 4.886921905584122, 4.974188368183839, 5.061454830783555, 5.148721293383272, 5.235987755982989, 5.323254218582705, 5.4105206811824215, 5.497787143782138, 5.585053606381854, 5.67232006898157, 5.759586531581287, 5.846852994181004, 5.93411945678072, 6.021385919380437, 6.108652381980153, 6.195918844579869, 6.283185307179586],
        [0.0, 0.08726646259971647, 0.17453292519943295, 0.2617993877991494, 0.3490658503988659, 0.4363323129985824, 0.5235987755982988, 0.6108652381980153, 0.6981317007977318, 0.7853981633974483, 0.8726646259971648, 0.9599310885968813, 1.0471975511965976, 1.1344640137963142, 1.2217304763960306, 1.3089969389957472, 1.3962634015954636, 1.4835298641951802, 1.5707963267948966, 1.658062789394613, 1.7453292519943295, 1.832595714594046, 1.9198621771937625, 2.007128639793479, 2.0943951023931953, 2.1816615649929116, 2.2689280275926285, 2.356194490192345, 2.443460952792061, 2.5307274153917776, 2.6179938779914944, 2.705260340591211, 2.7925268031909273, 2.879793265829644, 2.9670597284293603, 3.0543261910290767, 3.141592653589793, 3.2288591161895095, 3.316125578789226, 3.4033920413889422, 3.490658503988659, 3.5779249665883754, 3.6651914291880923, 3.7524578917878086, 3.839724354387525, 3.9269908169872415, 4.014257279586958, 4.101523742186674, 4.1887902047863905, 4.276056667386107, 4.363323129985824, 4.45058959258554, 4.537856055185257, 4.625122517784973, 4.71238898038469, 4.799655442984406, 4.886921905584122, 4.974188368183839, 5.061454830783555, 5.148721293383272, 5.235987755982989, 5.323254218582705, 5.4105206811824215, 5.497787143782138, 5.585053606381854, 5.67232006898157, 5.759586531581287, 5.846852994181004, 5.93411945678072, 6.021385919380437, 6.108652381980153, 6.195918844579869, 6.283185307179586],
        [0.0, 0.08726646259971647, 0.17453292519943295, 0.2617993877991494, 0.3490658503988659, 0.4363323129985824, 0.5235987755982988, 0.6108652381980153, 0.6981317007977318, 0.7853981633974483, 0.8726646259971648, 0.9599310885968813, 1.0471975511965976, 1.1344640137963142, 1.2217304763960306, 1.3089969389957472, 1.3962634015954636, 1.4835298641951802, 1.5707963267948966, 1.658062789394613, 1.7453292519943295, 1.832595714594046, 1.9198621771937625, 2.007128639793479, 2.0943951023931953, 2.1816615649929116, 2.2689280275926285, 2.356194490192345, 2.443460952792061, 2.5307274153917776, 2.6179938779914944, 2.705260340591211, 2.7925268031909273, 2.879793265829644, 2.9670597284293603, 3.0543261910290767, 3.141592653589793, 3.2288591161895095, 3.316125578789226, 3.4033920413889422, 3.490658503988659, 3.5779249665883754, 3.6651914291880923, 3.7524578917878086, 3.839724354387525, 3.9269908169872415, 4.014257279586958, 4.101523742186674, 4.1887902047863905, 4.276056667386107, 4.363323129985824, 4.45058959258554, 4.537856055185257, 4.625122517784973, 4.71238898038469, 4.799655442984406, 4.886921905584122, 4.974188368183839, 5.061454830783555, 5.148721293383272, 5.235987755982989, 5.323254218582705, 5.4105206811824215, 5.497787143782138, 5.585053606381854, 5.67232006898157, 5.759586531581287, 5.846852994181004, 5.93411945678072, 6.021385919380437, 6.108652381980153, 6.195918844579869, 6.283185307179586],
        [0.0, 0.2617993877991494, 0.5235987755982988, 0.7853981633974483, 1.0471975511965976, 1.3089969389957472, 1.5707963267948966, 1.832595714594046, 2.0943951023931953, 2.356194490192345, 2.6179938779914944, 2.879793265829644, 3.141592653589793, 3.4033920413889422, 3.6651914291880923, 3.9269908169872415, 4.1887902047863905, 4.45058959258554, 4.71238898038469, 4.974188368183839, 5.235987755982989, 5.497787143782138, 5.759586531581297, 6.021385919380437, 6.283185307179586],
        [0.0, 0.08726646259971647, 0.17453292519943295, 0.2617993877991494, 0.3490658503988659, 0.4363323129985824, 0.5235987755982988, 0.6108652381980153, 0.6981317007977318, 0.7853981633974483, 0.8726646259971648, 0.9599310885968813, 1.0471975511965976, 1.1344640137963142, 1.2217304763960306, 1.3089969389957472, 1.3962634015954636, 1.4835298641951802, 1.5707963267948966, 1.658062789394613, 1.7453292519943295, 1.832595714594046, 1.9198621771937625, 2.007128639793479, 2.0943951023931953, 2.1816615649929116, 2.2689280275926285, 2.356194490192345, 2.443460952792061, 2.5307274153917776, 2.6179938779914944, 2.705260340591211, 2.7925268031909273, 2.879793265829644, 2.9670597284293603, 3.0543261910290767, 3.141592653589793, 3.2288591161895095, 3.316125578789226, 3.4033920413889422, 3.490658503988659, 3.5779249665883754, 3.6651914291880923, 3.7524578917878086, 3.839724354387525, 3.9269908169872415, 4.014257279586958, 4.101523742186674, 4.1887902047863905, 4.276056667386107, 4.363323129985824, 4.45058959258554, 4.537856055185257, 4.625122517784973, 4.71238898038469, 4.799655442984406, 4.886921905584122, 4.974188368183839, 5.061454830783555, 5.148721293383272, 5.235987755982989, 5.323254218582705, 5.4105206811824215, 5.497787143782138, 5.585053606381854, 5.67232006898157, 5.759586531581287, 5.846852994181004, 5.93411945678072, 6.021385919380437, 6.108652381980153, 6.195918844579869, 6.283185307179586],
        [0.0, 0.04363323129985824, 0.08726646259971647, 0.1308996938995747, 0.17453292519943295, 0.2181661564992912, 0.2617993877991494, 0.30543261909900765, 0.3490658503988659, 0.39269908169872414, 0.4363323129985824, 0.4799655442984406, 0.5235987755982988, 0.5672320068981571, 0.6108652381980153, 0.6544984694978736, 0.6981317007977318, 0.7417649320975901, 0.7853981633974483, 0.8290313946973066, 0.8726646259971648, 0.9162978572970231, 0.9599310885968813, 1.0035643198967396, 1.0471975511965976, 1.090830782496456, 1.1344640137963142, 1.1780972450961724, 1.2217304763960306, 1.265363707695889, 1.3089969389957472, 1.3526301702956054, 1.3962634015954636, 1.4398966328953219, 1.4835298641951802, 1.5271630954950384, 1.5707963267948966, 1.614429558094755, 1.658062789394613, 1.701696020694471, 1.7453292519943295, 1.7889624832941877, 1.832595714594046, 1.8762289458939043, 1.9198621771937625, 1.9634954084936207, 2.007128639793479, 2.0507618710933373, 2.0943951023931953, 2.1380283336930536, 2.1816615649929116, 2.22529479629277, 2.2689280275926285, 2.3125612588924867, 2.356194490192345, 2.399827721492203, 2.443460952792061, 2.4870941840919194, 2.5307274153917776, 2.574360646691636, 2.6179938779914944, 2.6616271092913526, 2.705260340591211, 2.748893571891069, 2.7925268031909273, 2.8361600344907855, 2.879793265829644, 2.923426497129502, 2.9670597284293603, 3.0106929597292185, 3.0543261910290767, 3.097959422328935, 3.141592653589793, 3.185225884849651, 3.2288591161895095, 3.2724923474893677, 3.316125578789226, 3.359758810089084, 3.4033920413889422, 3.4470252726888005, 3.490658503988659, 3.534291735288517, 3.5779249665883754, 3.6215581978882336, 3.6651914291880923, 3.7088246604879505, 3.7524578917878086, 3.796091123087667, 3.839724354387525, 3.883357585687383, 3.9269908169872415, 3.9706240482870997, 4.014257279586958, 4.057890510886816, 4.101523742186674, 4.145156973486532, 4.1887902047863905, 4.232423436086249, 4.276056667386107, 4.319689898685965, 4.363323129985824, 4.406956361285682, 4.45058959258554, 4.494222823885398, 4.537856055185257, 4.581489286485115, 4.625122517784973, 4.668755749084831, 4.71238898038469, 4.756022211684548, 4.799655442984406, 4.843288674284264, 4.886921905584122, 4.930555136883981, 4.974188368183839, 5.017821599483697, 5.061454830783555, 5.105088062083414, 5.148721293383272, 5.19235452468313, 5.235987755982989, 5.279620987282847, 5.323254218582705, 5.366887449882563, 5.4105206811824215, 5.45415391248228, 5.497787143782138, 5.541420375081996, 5.585053606381854, 5.628686837681713, 5.67232006898157, 5.715953300281429, 5.759586531581287, 5.803219762881145, 5.846852994181004, 5.890486225480862, 5.93411945678072, 5.977752688080578, 6.021385919380437, 6.065019150680295, 6.108652381980153, 6.152285613280011, 6.195918844579869, 6.239552075879728, 6.283185307179586],
    ],
    "orbitRadii": [0, 82, 162, 335, 493, 662, 846, 251, 1080, 1322],
    "skillsPerOrbit": [1, 12, 24, 24, 72, 72, 72, 24, 72, 144],
}

CONNECTION_ART = {
    "ascendancy": "CharacterAscendancy",
    "default": "Character",
}

NODE_OVERLAY = {
    "Keystone": {
        "alloc": "KeystoneFrameAllocated",
        "path": "KeystoneFrameCanAllocate",
        "unalloc": "KeystoneFrameUnallocated",
    },
    "Normal": {
        "alloc": "PSSkillFrameActive",
        "path": "PSSkillFrameHighlighted",
        "unalloc": "PSSkillFrame",
    },
    "Notable": {
        "alloc": "NotableFrameAllocated",
        "path": "NotableFrameCanAllocate",
        "unalloc": "NotableFrameUnallocated",
    },
    "Socket": {
        "alloc": "JewelFrameAllocated",
        "path": "JewelFrameCanAllocate",
        "unalloc": "JewelFrameUnallocated",
    },
}


# ──────────────────────────────────────────────
# Build DDS coords for all classes + ascendancies
# ──────────────────────────────────────────────

def build_dds_coords(new_data, old_tree):
    """Build ddsCoords dict: copy old entries and update ascendancy backgrounds."""

    # Start with a deep copy of the old ddsCoords
    result = copy.deepcopy(old_tree.get("ddsCoords", {}))

    # Collect all class/ascendancy names that need ascendancy background dds entries
    asc_names = set()
    for cls in new_data["classes"]:
        asc_names.add(f"Classes{cls['name']}")
        for asc in cls.get("ascendancies", []):
            n = asc.get("name", "")
            if n and n != "None":
                asc_names.add(f"Classes{n}")

    # Build ascendancy background coords (sequential indices starting from 1)
    sorted_names = sorted(asc_names)
    asc_bg_coords = {}
    for idx, n in enumerate(sorted_names):
        asc_bg_coords[n] = idx + 1

    result["ascendancy-background_1500_1500_BC7.dds.zst"] = asc_bg_coords

    return result


# ──────────────────────────────────────────────
# Build ascendancyId → ascendancyName lookup
# ──────────────────────────────────────────────

def build_ascendancy_lookup(new_data):
    """Map ascendancy internal IDs (like 'Ranger1') to display names (like 'Deadeye')."""
    lookup = {}
    for cls in new_data["classes"]:
        for asc in cls.get("ascendancies", []):
            internal_id = asc.get("id", "")
            name = asc.get("name", "")
            if internal_id and name and name != "None":
                lookup[internal_id] = name
    return lookup


# ──────────────────────────────────────────────
# Build nodes
# ──────────────────────────────────────────────

def clean_stats(stats_list):
    """Clean stat strings: replace [Strength] etc. patterns."""
    if not stats_list:
        return []
    # The pattern "[Strength]" refers to the stat name; PoB handles this at display time
    return list(stats_list)


def build_nodes(new_data, asc_lookup):
    """Convert raw nodes to PoB format."""
    edges = new_data["edges"]
    raw_nodes = new_data["nodes"]
    skill_overrides = new_data.get("skillOverrides", {})

    # Build node_id → outgoing connection list
    # First: build a map of edge_id → edge so we can look up orbits
    edge_orbits = {}
    for idx, edge in enumerate(edges):
        frm = edge["from"]
        to = edge["to"]
        orbit = edge.get("orbit", 0)
        edge_orbits[(str(frm), str(to))] = orbit
        edge_orbits[(str(to), str(frm))] = -(orbit if orbit != 0 else 0)

    jewel_slot_set = set(int(x) for x in new_data.get("jewelSlots", []))

    nodes_out = {}
    for key, node in raw_nodes.items():
        if key == "root":
            continue

        # Convert node key to numeric ID
        skill_id = node.get("skill", key)
        if isinstance(skill_id, str):
            try:
                skill_id = int(skill_id)
            except ValueError:
                continue

        # Basic node fields
        new_node = {
            "skill": skill_id,
        }

        # Name, icon, stats - from node data or skillOverrides
        override = skill_overrides.get(str(key), {})
        name = node.get("name") or override.get("name", "")
        icon = node.get("icon") or override.get("icon", "")
        stats = node.get("stats") or override.get("stats", [])

        if name:
            new_node["name"] = name
        if icon:
            new_node["icon"] = icon
        if stats:
            new_node["stats"] = clean_stats(stats)

        # Position
        new_node["group"] = node.get("group", 0)
        new_node["orbit"] = node.get("orbit", 0)
        new_node["orbitIndex"] = node.get("orbitIndex", 0)

        # Connections
        connections = []
        outgoing = node.get("out", [])
        edge_indices = node.get("edges", [])
        for i, target_id in enumerate(outgoing):
            target_str = str(target_id)
            # Find orbit from edges
            key_str = str(key)
            edge_key = (key_str, target_str)
            orbit_val = edge_orbits.get(edge_key, 0)
            # Try to parse target as integer
            try:
                tgt_int = int(target_str)
            except ValueError:
                continue
            connections.append({
                "id": tgt_int,
                "orbit": orbit_val,
            })

        if connections:
            new_node["connections"] = connections

        # Type flags
        if node.get("isKeystone"):
            new_node["isKeystone"] = True
        if node.get("isNotable"):
            new_node["isNotable"] = True
        if node.get("isJewelSocket") or skill_id in jewel_slot_set:
            new_node["isJewelSocket"] = True
        if node.get("isMastery"):
            new_node["isMastery"] = True
        if node.get("isAscendancyStart"):
            new_node["isAscendancyStart"] = True
        if node.get("isMultipleChoice"):
            new_node["isMultipleChoice"] = True
        if node.get("isMultipleChoiceOption"):
            new_node["isMultipleChoiceOption"] = True
        if node.get("isBlighted"):
            new_node["isBlighted"] = True
        if node.get("isFree"):
            new_node["isFreeAllocate"] = True
        if node.get("isGenericAttribute"):
            new_node["isAttribute"] = True
            # Add attribute options (Str/Dex/Int) for generic attribute nodes
            attr_options = []
            for opt_id, opt_name, opt_icon, opt_stats in [
                (26297, "Strength", "Art/2DArt/SkillIcons/passives/plusstrength.png", ["+5 to [Strength]"]),
                (14927, "Dexterity", "Art/2DArt/SkillIcons/passives/plusdexterity.png", ["+5 to [Dexterity]"]),
                (57022, "Intelligence", "Art/2DArt/SkillIcons/passives/plusintelligence.png", ["+5 to [Intelligence]"]),
            ]:
                attr_options.append({
                    "id": opt_id,
                    "name": opt_name,
                    "icon": opt_icon,
                    "stats": opt_stats,
                })
            new_node["options"] = attr_options
        if node.get("hideConnection"):
            new_node["hideConnection"] = True

        # Ascendancy
        asc_id = node.get("ascendancyId", "")
        if asc_id:
            asc_name = asc_lookup.get(asc_id, "")
            if asc_name:
                new_node["ascendancyName"] = asc_name

        # Class start nodes
        class_start = node.get("classStartIndex", None)
        if class_start is not None:
            # classStartIndex is [class_idx, ...] in the raw data
            # Map to class names
            class_names = []
            for idx in class_start:
                if 0 <= idx < len(new_data["classes"]):
                    class_names.append(new_data["classes"][idx]["name"])
            if class_names:
                new_node["classesStart"] = class_names

        # Extra fields
        if node.get("activeEffectImage"):
            new_node["activeEffectImage"] = node["activeEffectImage"]
        if node.get("flavourText"):
            new_node["flavourText"] = node["flavourText"]
        if node.get("recipe"):
            new_node["recipe"] = node["recipe"]
        if node.get("unlockConstraint"):
            new_node["unlockConstraint"] = node["unlockConstraint"]
        if node.get("connectionArt"):
            new_node["connectionArt"] = node["connectionArt"]
        if node.get("grantedSkill"):
            new_node["grantedSkill"] = node["grantedSkill"]
        if node.get("grantedPassivePoints"):
            new_node["grantedPassivePoints"] = node["grantedPassivePoints"]
        if node.get("passivePointsGranted"):
            new_node["passivePointsGranted"] = node["passivePointsGranted"]
        if node.get("weaponPassivePointsGranted"):
            new_node["weaponPassivePointsGranted"] = node["weaponPassivePointsGranted"]
        if node.get("grantedStrength"):
            new_node["grantedStrength"] = node["grantedStrength"]
        if node.get("grantedDexterity"):
            new_node["grantedDexterity"] = node["grantedDexterity"]
        if node.get("grantedIntelligence"):
            new_node["grantedIntelligence"] = node["grantedIntelligence"]
        if node.get("containJewelSocket"):
            new_node["containJewelSocket"] = node["containJewelSocket"]
        if node.get("keystonesInRadius"):
            new_node["keystonesInRadius"] = node["keystonesInRadius"]

        # Options - for switchable nodes (e.g., ascendancy replacements)
        # The raw data doesn't have isSwitchable/options directly
        # Check if this asc start node has a counterpart
        if new_node.get("isAscendancyStart") and new_node.get("ascendancyName"):
            # We'll check if there are other ascendancies sharing the same class that might be replacements
            pass

        nodes_out[str(skill_id)] = new_node

    return nodes_out


# ──────────────────────────────────────────────
# Build groups
# ──────────────────────────────────────────────

def build_groups(new_data):
    """Convert groups to PoB format (list instead of dict)."""
    raw_groups = new_data["groups"]
    groups_list = []
    # Sort by group ID so the list is in order
    sorted_ids = sorted(raw_groups.keys(), key=lambda x: int(x) if isinstance(x, (int, str)) and str(x).isdigit() else float('inf'))
    for gid in sorted_ids:
        g = raw_groups[gid]
        groups_list.append({
            "nodes": [int(n) if str(n).isdigit() else n for n in g.get("nodes", []) if n != "root"],
            "orbits": list(g.get("orbits", [])),
            "x": g.get("x", 0),
            "y": g.get("y", 0),
        })
    return groups_list


# ──────────────────────────────────────────────
# Build classes
# ──────────────────────────────────────────────

def build_classes(new_data):
    """Convert classes to PoB format."""
    classes = []
    for cls in new_data["classes"]:
        cls_name = cls["name"]
        attrs = CLASS_ATTRS.get(cls_name, (7, 7, 7))
        int_id = CLASS_INTEGER_IDS.get(cls_name, 0)

        new_cls = {
            "ascendancies": [],
            "background": generate_class_background(cls_name),
            "base_dex": attrs[1],
            "base_int": attrs[2],
            "base_str": attrs[0],
            "integerId": int_id,
            "name": cls_name,
        }

        for asc in cls.get("ascendancies", []):
            asc_name = asc.get("name")
            if asc_name is None or asc_name == "None":
                continue

            new_asc = {
                "id": asc_name,
                "internalId": asc.get("id", ""),
                "name": asc_name,
                "background": generate_ascendancy_background(
                    asc_name,
                    asc.get("offsetX", 0),
                    asc.get("offsetY", 0),
                ),
            }
            new_cls["ascendancies"].append(new_asc)

        new_cls["ascendancies"].sort(key=lambda a: a.get("name", "") or "")

        classes.append(new_cls)

    return classes


# ──────────────────────────────────────────────
# Write tree.json
# ──────────────────────────────────────────────

def write_tree_json(tree_data, path):
    """Write tree.json with sorted keys for consistency."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(tree_data, f, indent="\t", sort_keys=True)
    print(f"Written: {path} ({os.path.getsize(path)} bytes)")


# ──────────────────────────────────────────────
# Write tree.lua
# ──────────────────────────────────────────────

def lua_quote(s):
    """Escape and quote a Lua string."""
    escaped = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
    return f'"{escaped}"'


def write_lua_table(f, value, indent=0):
    """Recursively write a Lua table."""
    prefix = "\t" * indent

    if value is None:
        f.write("null")
    elif isinstance(value, bool):
        f.write("true" if value else "false")
    elif isinstance(value, (int, float)):
        if math.isinf(value):
            f.write("math.huge")
        elif value == int(value):
            f.write(str(int(value)))
        else:
            f.write(str(value))
    elif isinstance(value, str):
        f.write(lua_quote(value))
    elif isinstance(value, list):
        if not value:
            f.write("{}")
        else:
            f.write("{\n")
            for i, item in enumerate(value):
                f.write(f"{prefix}\t[{i+1}]=")
                write_lua_table(f, item, indent + 1)
                f.write(",\n")
            f.write(f"{prefix}}}")
    elif isinstance(value, dict):
        if not value:
            f.write("{}")
        else:
            f.write("{\n")
            # Sort keys for deterministic output
            for k in sorted(value.keys(), key=lambda x: (isinstance(x, str), str(x))):
                if isinstance(k, str) and k.isidentifier() and k not in ("hexproof", "in"):
                    f.write(f"{prefix}\t{k}=")
                else:
                    f.write(f"{prefix}\t[{lua_quote(str(k))}]=")
                write_lua_table(f, value[k], indent + 1)
                f.write(",\n")
            f.write(f"{prefix}}}")
    else:
        f.write(str(value))


def write_tree_lua(tree_data, path):
    """Write tree.lua from tree_data."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("-- This file is automatically generated, do not edit!\n")
        f.write("-- Skill tree data (c) Grinding Gear Games\n\n")
        f.write("return ")
        write_lua_table(f, tree_data)
        f.write("\n")
    print(f"Written: {path} ({os.path.getsize(path)} bytes)")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("Path of Building 2 - Skill Tree Converter")
    print("Converting GGG 0.5.0 data.json → PoB tree.json + tree.lua")
    print("=" * 60)

    # Load input data
    print(f"\nReading: {INPUT_DATA_JSON}")
    with open(INPUT_DATA_JSON, "r") as f:
        new_data = json.load(f)

    # Load old tree.json for reference
    print(f"Reading reference: {OLD_TREE_JSON}")
    with open(OLD_TREE_JSON, "r") as f:
        old_tree = json.load(f)

    # Build ascendancy name lookup
    asc_lookup = build_ascendancy_lookup(new_data)
    print(f"Ascendancy lookup: {len(asc_lookup)} entries")

    # Build nodes
    print("Building nodes...")
    nodes = build_nodes(new_data, asc_lookup)
    print(f"  Nodes: {len(nodes)}")

    # Build groups
    print("Building groups...")
    groups = build_groups(new_data)
    print(f"  Groups: {len(groups)}")

    # Build classes
    print("Building classes...")
    classes = build_classes(new_data)
    print(f"  Classes: {len(classes)}")

    # Build DDS coords
    print("Building DDS coords...")
    dds_coords = build_dds_coords(new_data, old_tree)
    print(f"  DDS textures: {len(dds_coords)}")

    # Assemble tree data
    tree_data = {
        "assets": ASSETS,
        "classes": classes,
        "connectionArt": CONNECTION_ART,
        "constants": CONSTANTS,
        "ddsCoords": dds_coords,
        "groups": groups,
        "jewelSlots": new_data.get("jewelSlots", []),
        "max_x": new_data.get("max_x", old_tree.get("max_x", 0)),
        "max_y": new_data.get("max_y", old_tree.get("max_y", 0)),
        "min_x": new_data.get("min_x", old_tree.get("min_x", 0)),
        "min_y": new_data.get("min_y", old_tree.get("min_y", 0)),
        "nodeOverlay": NODE_OVERLAY,
        "nodes": nodes,
        "tree": new_data.get("tree", "Default"),
    }

    # Write output
    print(f"\nWriting to: {OUTPUT_DIR}")
    write_tree_json(tree_data, OUTPUT_TREE_JSON)
    write_tree_lua(tree_data, OUTPUT_TREE_LUA)

    # Summary
    total_conn = sum(len(n.get("connections", [])) for n in nodes.values())
    total_keystones = sum(1 for n in nodes.values() if n.get("isKeystone"))
    total_notables = sum(1 for n in nodes.values() if n.get("isNotable"))
    total_sockets = sum(1 for n in nodes.values() if n.get("isJewelSocket"))
    total_masteries = sum(1 for n in nodes.values() if n.get("isMastery"))
    total_attributes = sum(1 for n in nodes.values() if n.get("isAttribute"))

    print(f"\n{'=' * 60}")
    print(f"Tree: {tree_data['tree']}")
    print(f"  Classes: {len(classes)}")
    print(f"  Nodes: {len(nodes)}")
    print(f"  Connections: {total_conn}")
    print(f"  Groups: {len(groups)}")
    print(f"  Keystones: {total_keystones}")
    print(f"  Notables: {total_notables}")
    print(f"  Jewel Sockets: {total_sockets}")
    print(f"  Masteries: {total_masteries}")
    print(f"  Attribute Nodes: {total_attributes}")
    print(f"  Bounding Box: ({tree_data['min_x']}, {tree_data['min_y']}) - ({tree_data['max_x']}, {tree_data['max_y']})")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
