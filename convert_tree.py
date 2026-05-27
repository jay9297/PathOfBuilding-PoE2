#!/usr/bin/env python3
"""Convert GGG poe2-skilltree-export data.json to PoB tree.json/tree.lua format."""

import json
import math
import os
import sys

def build_edge_map(edges):
    """Build a map from (from_id, to_id) -> edge info."""
    edge_map = {}
    for edge in edges:
        frm = edge['from']
        to = edge['to']
        edge_map[(frm, to)] = edge
    return edge_map

def strip_ggg_tags(text):
    """Strip GGG tagged format [Tag] or [Tag|Display] -> Display."""
    import re
    # [Tag|Display] -> Display, [Tag] -> Tag
    return re.sub(r'\[([^|\[\]]+?\|)?([^|\[\]]+?)\]', r'\2', text)

def convert_node(gid, node, edge_map, skill_overrides):
    """Convert a GGG format node to PoB format."""
    if 'skill' not in node:
        return None
    
    skill = node['skill']
    if not isinstance(skill, int):
        return None
    
    pob_node = {
        'skill': skill,
        'group': node['group'],
        'orbit': node['orbit'],
        'orbitIndex': node['orbitIndex'],
    }
    
    if 'name' in node and node['name']:
        pob_node['name'] = node['name']
    if 'icon' in node and node['icon']:
        pob_node['icon'] = node['icon']
    
    # Convert connections from 'out' array using edge_map for orbit info
    connections = []
    if 'out' in node and node['out']:
        for target_id in node['out']:
            conn_orbit = 0
            edge_key = (skill, target_id)
            rev_edge_key = (target_id, skill)
            if edge_key in edge_map:
                conn_orbit = edge_map[edge_key].get('orbit', 0)
            elif rev_edge_key in edge_map:
                conn_orbit = edge_map[rev_edge_key].get('orbit', 0)
            # Ensure id is an integer
            try:
                target_id_int = int(target_id)
            except (ValueError, TypeError):
                target_id_int = target_id
            connections.append({
                'id': target_id_int,
                'orbit': conn_orbit
            })
    if connections:
        pob_node['connections'] = connections
    
    # Stats - strip GGG tags
    if 'stats' in node and node['stats']:
        pob_node['stats'] = [strip_ggg_tags(s) for s in node['stats']]
    
    # Node type flags
    if node.get('isNotable'):
        pob_node['isNotable'] = True
    if node.get('isKeystone'):
        pob_node['isKeystone'] = True
    if node.get('isJewelSocket'):
        pob_node['isJewelSocket'] = True
    if node.get('isAscendancyStart'):
        pob_node['isAscendancyStart'] = True
    if node.get('isSwitchable'):
        pob_node['isSwitchable'] = True
    if node.get('isMultipleChoice'):
        pob_node['isMultipleChoice'] = True
    if node.get('isMultipleChoiceOption'):
        pob_node['isMultipleChoiceOption'] = True
    if node.get('isFreeAllocate'):
        pob_node['isFreeAllocate'] = True
    if node.get('containJewelSocket'):
        pob_node['containJewelSocket'] = True
    if node.get('isAttribute'):
        pob_node['isAttribute'] = True
    if node.get('isOnlyImage'):
        pob_node['isOnlyImage'] = True
    if node.get('applyToArmour'):
        pob_node['applyToArmour'] = True
    
    # Ascendancy info
    if 'ascendancyId' in node:
        # We'll resolve ascendancyName later from class data
        # For now just store the ascendancyId for later mapping
        pass
    
    # Class starts (we resolve index->name in main() using ggg_classes_order)
    
    # Flavour text
    if 'flavourText' in node and node['flavourText']:
        if isinstance(node['flavourText'], list):
            pob_node['flavourText'] = '\\n'.join(node['flavourText'])
        else:
            pob_node['flavourText'] = node['flavourText']
    
    # Mastery active effect
    if 'activeEffectImage' in node:
        pob_node['activeEffectImage'] = node['activeEffectImage']
    
    # Connection art (for ascendancy unlock nodes)
    if 'connectionArt' in node:
        pob_node['connectionArt'] = node['connectionArt']
    
    # Unlock constraint (for ascendancy unlock)
    if 'unlock' in node:
        unlock = node['unlock']
        pob_node['unlockConstraint'] = unlock
    
    # Oils / recipe
    if 'oils' in node:
        pob_node['recipe'] = node['oils']
    
    # Options (for switchable nodes)
    if 'swap' in node:
        swap = node['swap']
        options = {}
        for class_name, swap_info in swap.items():
            options[class_name] = {
                'id': swap_info.get('skill', swap_info.get('id')),
                'name': swap_info.get('name', ''),
                'icon': swap_info.get('icon', ''),
                'stats': swap_info.get('stats', []),
            }
        pob_node['options'] = options
    
    # Attribute options (for attribute nodes)
    if node.get('isAttribute') and 'options' in node:
        pob_node['options'] = node['options']
    
    # Ascendancy node name override (ascendancy start nodes)
    if 'ascendancyId' in node and node.get('isAscendancyStart'):
        pass  # name is already set
    
    # Spirit granted
    if 'spirit' in node and node['spirit'] > 0:
        if 'stats' not in pob_node:
            pob_node['stats'] = []
        pob_node['stats'].append('Grants ' + str(node['spirit']) + ' Spirit')
    
    # Granted skill
    if 'grantedSkill' in node:
        if 'stats' not in pob_node:
            pob_node['stats'] = []
        pob_node['stats'].append('Grants Skill: <underline>{' + node.get('name', 'Unknown') + '}')
    
    return pob_node

def convert_classes(ggg_classes, class_start_nodes):
    """Convert GGG classes to PoB format including ascendancies."""
    # Map class names to integer IDs (matching PoB convention)
    class_name_to_int_id = {
        'Marauder': 0, 'Witch': 1, 'Ranger': 2, 'Duelist': 3,
        'Shadow': 4, 'Templar': 5, 'Warrior': 6, 'Sorceress': 7,
        'Huntress': 8, 'Mercenary': 9, 'Monk': 10, 'Druid': 11
    }
    
    # base attributes
    base_attrs = {
        'Marauder': (15, 7, 7),
        'Witch': (7, 7, 15),
        'Ranger': (7, 15, 7),
        'Duelist': (11, 11, 7),
        'Shadow': (7, 11, 11),
        'Templar': (11, 7, 11),
        'Warrior': (15, 7, 7),
        'Sorceress': (7, 7, 15),
        'Huntress': (7, 14, 8),
        'Mercenary': (11, 11, 7),
        'Monk': (8, 11, 11),
        'Druid': (14, 7, 9),
    }
    
    pob_classes = []
    for cls in ggg_classes:
        name = cls['name']
        int_id = class_name_to_int_id.get(name, 0)
        b = base_attrs.get(name, (7, 7, 7))
        
        # Build ascendancies
        ascendancies = []
        for asc in cls.get('ascendancies', []):
            asc_name = asc.get('name')
            if not asc_name or asc_name == 'None':
                continue
            ascendancies.append({
                'id': asc_name,
                'name': asc_name,
                'internalId': asc.get('id', asc_name),
                'replace': asc.get('replace', None),
                'background': asc.get('background', {
                    'image': 'Classes' + asc_name,
                    'section': 'AscendancyBackground',
                    'x': 0, 'y': 0, 'width': 1500, 'height': 1500
                })
            })
        
        class_def = {
            'name': name,
            'integerId': int_id,
            'base_str': b[0],
            'base_dex': b[1],
            'base_int': b[2],
            'ascendancies': ascendancies,
            'background': cls.get('background', {
                'active': {'width': 2000, 'height': 2000},
                'bg': {'width': 2000, 'height': 2000},
                'image': 'Classes' + name,
                'section': 'AscendancyBackground',
                'x': 0, 'y': 0, 'width': 1500, 'height': 1500
            })
        }
        
        pob_classes.append(class_def)
    
    return pob_classes

def convert_groups(ggg_groups):
    """Convert GGG groups to PoB format."""
    pob_groups = {}
    for gid in sorted(ggg_groups.keys(), key=lambda x: int(x) if x.isdigit() else 0):
        group = ggg_groups[gid]
        gid_int = int(gid) if gid.isdigit() else 0
        pob_groups[gid_int] = {
            'x': group['x'],
            'y': group['y'],
            'orbits': group.get('orbits', []),
            'nodes': [int(n) for n in group.get('nodes', [])],
        }
    return pob_groups

def convert_jewel_slots(ggg_jewel_slots):
    """Convert GGG jewel slots to PoB format."""
    return [int(s) for s in ggg_jewel_slots]

def compute_constants(pob_nodes, pob_groups):
    """Compute constants from the tree data."""
    # Orbit radii (these are standard in PoE2)
    orbit_radii = [0, 82, 162, 335, 493, 662, 846, 251, 1080, 1322]
    
    # Calculate skills per orbit and orbit angles
    max_orbit = 0
    for nid, node in pob_nodes.items():
        if node['orbit'] > max_orbit:
            max_orbit = node['orbit']
    
    skills_per_orbit = {}
    orbit_angles = {}
    
    for orbit_idx in range(max_orbit + 1):
        max_pos = 1
        for nid, node in pob_nodes.items():
            if node['orbit'] == orbit_idx:
                if node['orbitIndex'] + 1 > max_pos:
                    max_pos = node['orbitIndex'] + 1
        
        # Round up to nearest 12
        if orbit_idx == 0:
            max_pos = max_pos
        else:
            max_pos = math.ceil(max_pos / 12) * 12
        
        skills_per_orbit[orbit_idx + 1] = max_pos
        
        # Calculate angles
        angles = []
        num_nodes = max_pos
        if num_nodes == 16:
            angles_deg = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330]
        elif num_nodes == 40:
            angles_deg = [0, 10, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100, 110, 120, 130, 135, 140, 150, 160, 170, 180, 190, 200, 210, 220, 225, 230, 240, 250, 260, 270, 280, 290, 300, 310, 315, 320, 330, 340, 350]
        else:
            angles_deg = [360 * i / num_nodes for i in range(num_nodes)]
        orbit_angles[orbit_idx + 1] = [math.radians(d) for d in angles_deg]
    
    return {
        'PSSCentreInnerRadius': 130,
        'characterAttributes': {
            'Dexterity': 1,
            'Intelligence': 2,
            'Strength': 0
        },
        'classes': {
            'StrDexIntClass': 0,
            'StrClass': 1,
            'DexClass': 2,
            'IntClass': 3,
            'StrDexClass': 4,
            'StrIntClass': 5,
            'DexIntClass': 6
        },
        'skillsPerOrbit': skills_per_orbit,
        'orbitAnglesByOrbit': orbit_angles,
        'orbitRadii': orbit_radii,
    }

def resolve_ascendancy_names(pob_nodes, ggg_data):
    """Resolve ascendancyId to ascendancyName using class data."""
    # Build ascendancy ID map: internal ID (Druid1, Ranger1) -> display name (Oracle, Deadeye)
    asc_id_to_name = {}
    for cls in ggg_data['classes']:
        for asc in cls.get('ascendancies', []):
            asc_id = asc.get('id', '')
            asc_name = asc.get('name', '')
            if asc_id and asc_name:
                asc_id_to_name[asc_id] = asc_name
    
    for nid, node in pob_nodes.items():
        ggg_nid = str(nid)
        if ggg_nid not in ggg_data['nodes']:
            continue
        ggg_node = ggg_data['nodes'][ggg_nid]
        ascendancy_id = ggg_node.get('ascendancyId', '')
        if ascendancy_id and ascendancy_id in asc_id_to_name:
            node['ascendancyName'] = asc_id_to_name[ascendancy_id]
        elif ascendancy_id:
            # Use the internal ID as a fallback name
            node['ascendancyName'] = ascendancy_id

def main():
    # Load GGG data
    with open('/tmp/data_0_5.json') as f:
        ggg_data = json.load(f)
    
    # Load old PoB data for reference (rendering assets, etc.)
    old_tree_path = os.path.join(os.path.dirname(__file__), 'src', 'TreeData', '0_4', 'tree.json')
    with open(old_tree_path) as f:
        old_data = json.load(f)
    
    # Build edge map
    edge_map = build_edge_map(ggg_data['edges'])
    
    # Convert nodes
    pob_nodes = {}
    for nid, node in ggg_data['nodes'].items():
        pob_node = convert_node(nid, node, edge_map, ggg_data.get('skillOverrides', {}))
        if pob_node:
            pob_nodes[pob_node['skill']] = pob_node
    
    # Convert classes first (so we know which ascendancies are valid)
    pob_classes = convert_classes(ggg_data['classes'], pob_nodes)
    
    # Build set of valid ascendancy names
    valid_ascendancy_names = set()
    for cls in pob_classes:
        for asc in cls.get('ascendancies', []):
            valid_ascendancy_names.add(asc['name'])
    
    # Resolve ascendancy names
    resolve_ascendancy_names(pob_nodes, ggg_data)
    
    # Filter out nodes with unreleased ascendancies (internal IDs not in valid_ascendancy_names)
    unreleased_asc_internal_ids = {'Marauder1', 'Marauder2', 'Marauder3', 'Duelist1', 'Duelist2', 'Duelist3', 'Shadow1', 'Shadow2', 'Shadow3', 'Templar1', 'Templar2', 'Templar3', 'Ranger2', 'Druid3'}
    nodes_to_remove = set()
    for nid, node in list(pob_nodes.items()):
        if node.get('ascendancyName') in unreleased_asc_internal_ids:
            nodes_to_remove.add(nid)
    for nid in nodes_to_remove:
        del pob_nodes[nid]
    if nodes_to_remove:
        print(f'Filtered out {len(nodes_to_remove)} nodes with unreleased ascendancies')
    
    # Clean up connections that point to removed nodes (all IDs are ints now)
    for nid, node in pob_nodes.items():
        if node.get('connections'):
            node['connections'] = [c for c in node['connections'] if c['id'] not in nodes_to_remove]
    
    # Resolve classStartIndex values to class names
    # Build class index -> name mapping from GGG classes array
    ggg_class_names = [cls['name'] for cls in ggg_data['classes']]
    for nid_str, ggg_node in ggg_data['nodes'].items():
        if 'classStartIndex' in ggg_node and ggg_node['classStartIndex']:
            skill = ggg_node.get('skill')
            if skill and skill in pob_nodes:
                class_names = [ggg_class_names[idx] for idx in ggg_node['classStartIndex']]
                pob_nodes[skill]['classesStart'] = class_names
    
    # Add attribute node options
    skill_overrides = ggg_data.get('skillOverrides', {})
    for override_id_str, override in skill_overrides.items():
        override_id = int(override_id_str)
        if override_id in pob_nodes:
            if 'stats' not in pob_nodes[override_id]:
                pob_nodes[override_id]['stats'] = []
            pob_nodes[override_id]['stats'] = override.get('stats', pob_nodes[override_id].get('stats', []))
            if 'name' in override:
                pob_nodes[override_id]['name'] = override['name']
            if 'icon' in override:
                pob_nodes[override_id]['icon'] = override['icon']
    
    # Convert groups
    pob_groups = convert_groups(ggg_data['groups'])
    
    # Convert jewel slots
    pob_jewel_slots = convert_jewel_slots(ggg_data['jewelSlots'])
    
    # Compute constants
    constants = compute_constants(pob_nodes, pob_groups)
    
    # Build final tree
    tree = {
        'tree': 'Default',
        'min_x': ggg_data.get('min_x', -22597),
        'min_y': ggg_data.get('min_y', -18720),
        'max_x': ggg_data.get('max_x', 21814),
        'max_y': ggg_data.get('max_y', 20053),
        'assets': old_data['assets'],
        'classes': pob_classes,
        'connectionArt': old_data.get('connectionArt', {'default': 'Character', 'ascendancy': 'CharacterAscendancy'}),
        'constants': constants,
        'ddsCoords': old_data.get('ddsCoords', {}),
        'groups': pob_groups,
        'jewelSlots': pob_jewel_slots,
        'nodeOverlay': old_data.get('nodeOverlay', {}),
        'nodes': pob_nodes,
    }
    
    # Output directory
    out_dir = os.path.join(os.path.dirname(__file__), 'src', 'TreeData', '0_5')
    os.makedirs(out_dir, exist_ok=True)
    
    # Write JSON
    json_path = os.path.join(out_dir, 'tree.json')
    with open(json_path, 'w') as f:
        json.dump(tree, f)
    print(f'Wrote {json_path} ({os.path.getsize(json_path)} bytes)')
    
    # Write Lua
    lua_path = os.path.join(out_dir, 'tree.lua')
    with open(lua_path, 'w') as f:
        f.write('return ')
        write_lua_table(f, tree, 0)
    print(f'Wrote {lua_path} ({os.path.getsize(lua_path)} bytes)')
    
    print(f'\nSummary:')
    print(f'  Nodes: {len(pob_nodes)}')
    print(f'  Groups: {len(pob_groups)}')
    print(f'  Classes: {len(pob_classes)}')
    print(f'  Jewel slots: {len(pob_jewel_slots)}')

def write_lua_table(f, val, indent):
    """Write a Python value as a Lua table."""
    prefix = '\t' * indent
    
    if val is None:
        f.write('nil')
    elif isinstance(val, bool):
        f.write('true' if val else 'false')
    elif isinstance(val, (int, float)):
        if isinstance(val, float) and val == int(val):
            f.write(str(int(val)))
        elif isinstance(val, float):
            f.write(f'{val:.10g}')
        else:
            f.write(str(val))
    elif isinstance(val, str):
        # Escape Lua strings
        escaped = val.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
        f.write(f'"{escaped}"')
    elif isinstance(val, list):
        if not val:
            f.write('{}')
        else:
            f.write('{\n')
            for i, item in enumerate(val):
                f.write(f'{prefix}\t[{(i+1)}]=')
                write_lua_table(f, item, indent + 1)
                f.write(',\n')
            f.write(f'{prefix}}}')
    elif isinstance(val, dict):
        if not val:
            f.write('{}')
        else:
            # Check if dict is array-like (all integer keys)
            keys = list(val.keys())
            all_int = all(isinstance(k, (int, float)) for k in keys)
            
            f.write('{\n')
            for k in sorted(keys, key=lambda x: (isinstance(x, str), str(x))):
                if isinstance(k, str):
                    # Check if key is a valid Lua identifier
                    if k.isidentifier():
                        f.write(f'{prefix}\t{k}=')
                    else:
                        f.write(f'{prefix}\t["{k}"]=')
                else:
                    f.write(f'{prefix}\t[{int(k)}]=')
                write_lua_table(f, val[k], indent + 1)
                f.write(',\n')
            f.write(f'{prefix}}}')
    else:
        f.write(f'"{str(val)}"')

if __name__ == '__main__':
    main()
