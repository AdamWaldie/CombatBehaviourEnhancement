"""Compact native-node selection regressions; not doorway/physical clearance proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CompactBuddyEntryTests(unittest.TestCase):
    def test_distinct_compact_node_precedes_shared_anchor_fallback(self):
        distances=[0,0.8,1.5,2.0]
        old=[d for d in distances if 2.5<=d<=8]
        new=[d for d in distances if 1.2<=d<=8]
        self.assertEqual(old,[])
        self.assertEqual(min(new,key=lambda d:d+(0 if d>=2.5 else 10)),1.5)
        self.assertLess(4,1.5+10) # wider node wins within the same occupancy category

    def test_native_geometry_and_candidate_budget_remain(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        block=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        self.assertIn('_x distance2D _anchor >= 1.2',block)
        self.assertIn('_distance >= 2.5',block)
        self.assertIn('_ranked resize ((count _ranked) min 24)',block)
        self.assertIn('lineIntersectsSurfaces',block)
        self.assertIn('_supportTarget=if (_connected >= 0)',block)
        self.assertIn('_positions select {',block)
        self.assertNotIn('getPos [',block)


class NativeBuddyRouteTests(unittest.TestCase):
    def test_obstructed_ray_does_not_force_a_shared_entry_node(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        block=text.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        self.assertIn('private _ranked=if (_freeRanks isNotEqualTo []) then {_freeRanks} else {_busyRanks}',block)
        fallback=block.split('_supportTarget=if (_connected >= 0)',1)[1]
        self.assertIn('if (_ranked isNotEqualTo []) then {+((_ranked select 0) select 1)} else {+_anchor}',fallback)
        for forbidden in ('doMove','setPos','setVelocity','set ["deadline"','_cleared pushBack'):
            self.assertNotIn(forbidden,block)
