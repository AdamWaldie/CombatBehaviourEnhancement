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
        for name in ('cortexClearBuilding','indoorActorNodeSelect','indoorActorOperation','cortexGarrison'):
            text=(ROOT/f'addons/infantry/functions/{name}.sqf').read_text()
            self.assertIn('call CBE_fnc_BuildingRoofTop',text)
            self.assertNotIn('vectorAdd [0,0,10]',text)

        garrison=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        planning=garrison.split('private _building=_x;',1)[1].split('} forEach (_buildings select [0,64]);',1)[0]
        self.assertEqual(planning.count('call CBE_fnc_BuildingRoofTop'),1)
        self.assertLess(planning.index('call CBE_fnc_BuildingRoofTop'),planning.index('private _position=_x;'))
        self.assertIn('if (!finite _roofTop || {_roofTop == -1e12}) exitWith {}',planning)
        self.assertNotIn('vectorAdd [0,0,15]',planning)

    def test_invalid_or_below_actor_roof_limit_cannot_query_downward(self):
        checks={
            'cortexGarrison':'_roofTop > (_positionASL select 2)+1',
            'buildingOperationStep':'_roomRoofTop <= (_actual select 2)+0.5',
            'cortexClearBuilding':'_roofTop <= (_positionASL select 2)+0.5',
            'indoorActorNodeSelect':'_roofTop > (_asl select 2)+0.4',
            'indoorActorOperation':'_roofTop > (_actualASL select 2)+0.4',
        }
        for name,guard in checks.items():
            text=(ROOT/f'addons/infantry/functions/{name}.sqf').read_text()
            self.assertIn(guard,text)
            # The operation has separate arrival and observation-commit roof checks.
            if name == 'indoorActorOperation':
                commit=text.split('private _visitRoofTop=',1)[1].split('private _memoryState=',1)[0]
                self.assertLess(commit.index('_visitRoofTop <= (_visitASL select 2)+0.4'),
                                commit.index('lineIntersectsSurfaces'))
                text=text.split('if (_phase == "APPROACH") exitWith {',1)[1]
            after=text.split('call CBE_fnc_BuildingRoofTop',1)[1]
            self.assertLess(after.index(guard),after.index('lineIntersectsSurfaces'))
        # The helper's invalid sentinel must never satisfy an upward query at ordinary ASL.
        for actor_z in (-500,0,1500):
            self.assertFalse(-1e12 > actor_z+0.4)

    def test_native_planning_allowance_requires_matching_owned_move_and_does_not_renew_clocks(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        grace=text.split('private _retryDelay=[12,4] select _commandEnded;',1)[1].split('if (_now-_lastProgress > _retryDelay',1)[0]
        for guard in ('!_commandEnded','call _ownsCurrentMove','getUnitState _point in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY","BUSY"]'):
            self.assertLess(grace.index(guard),grace.index('_retryDelay=30'))
        for renewal in ('_lastProgress=','_retries=','set ["deadline"','set ["hardDeadline"','doMove'):
            self.assertNotIn(renewal,grace)
