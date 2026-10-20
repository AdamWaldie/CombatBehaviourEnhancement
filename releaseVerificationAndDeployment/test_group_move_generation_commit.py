"""An obsolete operation must not adopt or insert a successor's group route."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(path):return (ROOT/path).read_text(encoding='utf-8')
class GroupMoveGeneration(unittest.TestCase):
    def test_explicit_generation_is_authority_not_only_cleanup_metadata(self):
        text=src('addons/infantry/functions/cortexGroupMove.sqf')
        helper=text.split('private _generationCurrent={',1)[1].split('private _desired=',1)[0] if 'private _desired=' in text else text.split('private _generationCurrent={',1)[1].split('private _desired =',1)[0]
        for proof in ('local _group','CBE_AIPass_Epoch','_live getOrDefault ["generation",-2]',
                      '_live getOrDefault ["ownerEpoch",-1]','count _live == 0'):
            self.assertIn(proof,helper)
        self.assertLess(text.index('call _generationCurrent'),text.index('CBE_fnc_CortexZeusMark'))
        same=text.split('if (_sameRequest) exitWith {',1)[1].split('// A curator',1)[0]
        self.assertIn('isNil {',same)
        self.assertLess(same.index('call _generationCurrent'),same.index('_intent set'))
        commit=text.split('private _committed=[grpNull,-1];',1)[1]
        self.assertLess(commit.index('isNil {'),commit.index('addWaypoint'))
        self.assertLess(commit.index('call _generationCurrent'),commit.index('CBE_fnc_CortexGroupMoveClear'))
        self.assertEqual(commit.count('call _generationCurrent'),2)
    def test_both_reverse_fallback_callers_pass_original_generation(self):
        tick=src('addons/infantry/functions/cortexGroupTick.sqf')
        vehicle=src('addons/vehicles/functions/cortexVehicles.sqf')
        self.assertIn('[_group,_escape,40,"MOVE",_reverseRecord select 1]',tick)
        self.assertIn('[_group, _away, 40,"MOVE",_operation get "generation"]',vehicle)
        tick_body=tick.split('private _reverseResult=',1)[1].split('private _combined',1)[0]
        self.assertLess(tick_body.index('isNil {'),tick_body.index('[_group,_escape,40'))
        self.assertIn('"CBE_VehicleReverse",[]]) isEqualTo []',tick_body)
        initial=vehicle.split('private _reverse=[_group,_state,_vehicle',1)[1].split('_state set ["movementLease"',1)[0]
        self.assertLess(initial.index('isNil {'),initial.index('CBE_fnc_CortexGroupMove'))
        self.assertIn('_reverseNow isEqualTo []',initial)
if __name__=='__main__': unittest.main()
