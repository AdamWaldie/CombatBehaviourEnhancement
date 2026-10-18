"""Interior receipt contracts; not physical entry or hostile-room safety."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClearObserverInteriorTests(unittest.TestCase):
    def test_exterior_and_foreign_roof_cannot_grant_a_visit(self):
        def receipt(inside,roof_hits,segment_hits):
            return inside and bool(roof_hits) and roof_hits[0]=="target" and not segment_hits
        self.assertFalse(receipt(False,["target"],[]))
        self.assertFalse(receipt(True,[],[]))
        self.assertFalse(receipt(True,["neighbor","target"],[]))
        self.assertFalse(receipt(True,["target"],["neighbor-wall"]))
        self.assertFalse(receipt(True,["target"],["prop"]))
        self.assertTrue(receipt(True,["target"],[]))

    def test_actual_observer_and_segment_share_existing_budget(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        observer=s.split('private _observerInside={',1)[1].split('private _roomSegmentClear=',1)[0]
        for evidence in ('getPosASL _actor','worldToModel (getPosATL _actor)',
                         '_roomGeometryBudget <= 0','_roomGeometryBudget=_roomGeometryBudget-1',
                         '_roof select 0','_interiorObservers set [_key,_ownedRoof]'):
            self.assertIn(evidence,observer)
        visit=s.split('private _atPosition=_actual vectorDistance',1)[1].split('if (_atPosition)',1)[0]
        self.assertIn('[_visitor] call _observerInside',visit)
        self.assertIn('call _roomSegmentClear',visit)
        self.assertIn('private _clear=_hits isEqualTo [];',s)
        self.assertEqual(s.count('_job set ["roomGeometryChecksLast",0]'),1)
        self.assertLess(s.index('_job set ["roomGeometryChecksLast",0]'),s.index('private _observerInside='))

    def test_roof_limit_uses_all_model_corners_in_world_space_once_per_callback(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        observer=s.split('private _observerInside={',1)[1].split('private _roomSegmentClear=',1)[0]
        self.assertIn('if (_roomBuildingBounds isEqualTo [])',observer)
        self.assertIn('if (_roomRoofTop == -1e12)',observer)
        helper=(ROOT/'addons/infantry/functions/buildingRoofTop.sqf').read_text()
        for axis in range(3):
            self.assertIn(f'forEach [_low select {axis},_high select {axis}]',helper)
        self.assertIn('modelToWorldWorld [_cx,_cy,_x]',helper)
        self.assertIn('_top max (_corner select 2)',helper)
        self.assertIn('[_house,_bounds] call CBE_fnc_BuildingRoofTop',observer)
        self.assertIn('[_actual select 0,_actual select 1,_roomRoofTop]',observer)
        self.assertNotIn('_actual vectorAdd [0,0,10]',observer)
        self.assertEqual(observer.count('lineIntersectsSurfaces'),1)

    def test_corner_max_covers_tall_and_tilted_roofs_without_nearest_hit_shortcut(self):
        import itertools
        # Vertical projection of an affine model transform attains its maximum at a corner.
        for low,high,origin,up in [((-5,-8,0),(5,8,25),100,(0,0,1)),
                                   ((-4,-6,-2),(4,6,18),30,(0.3,-0.4,0.866))]:
            top=max(origin+sum(c*v for c,v in zip(corner,up))
                    for corner in itertools.product(*zip(low,high)))+1
            for fractions in itertools.product((0,0.25,0.5,0.75,1),repeat=3):
                point=[a+(b-a)*f for a,b,f in zip(low,high,fractions)]
                self.assertGreater(top,origin+sum(c*v for c,v in zip(point,up)))

    def test_discovery_and_natural_indoor_paths_share_model_roof_limit(self):
        for name in ('cortexClearBuilding','indoorActorNodeSelect','indoorActorOperation'):
            text=(ROOT/f'addons/infantry/functions/{name}.sqf').read_text()
            self.assertIn('call CBE_fnc_BuildingRoofTop',text)
            self.assertNotIn('vectorAdd [0,0,10]',text)
