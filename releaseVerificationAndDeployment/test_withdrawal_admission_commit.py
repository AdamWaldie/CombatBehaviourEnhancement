"""Retreat state requires a matching admitted native leg, not only a start attempt."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class WithdrawalAdmission(unittest.TestCase):
    def test_retreat_state_follows_current_admitted_reverse_or_waypoint(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicles.sqf').read_text(encoding='utf-8')
        body=text.split('private _withdrawStarted=false;',1)[1].split('if (!_withdrawStarted)',1)[0]
        for proof in ('isNil {','isEqualTo _state','"generation",-1','"ownerEpoch",-1',
                      '_reverse == "REVERSE"','CBE_VehicleReverseOwner','_intent getOrDefault ["waypoint",[]]',
                      '_intent getOrDefault ["operationGeneration",-1]','if (_moveAccepted'):
            self.assertLess(body.index(proof),body.index('_state set ["retreatTarget"'))
        self.assertLess(body.index('if (_moveAccepted'),body.index('_withdrawn pushBackUnique'))
        self.assertIn('(_operation get "startedAt")+120',body)
        self.assertNotIn('["VEHICLE_WITHDRAW",time+120]',body)
    def test_refusal_retires_matching_incomplete_operation_without_retreat(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicles.sqf').read_text(encoding='utf-8')
        body=text.split('if (!_withdrawStarted) then {',1)[1].split('// Gunner priorities',1)[0]
        self.assertIn('"INCOMPLETE","MOVEMENT_REJECTED"',body)
        self.assertIn('(_ended select 2) == (_operation get "generation")',body)
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) == 0',body)
        self.assertNotIn('CBE_fnc_CortexSetPhase',body)
        self.assertNotIn('"MOVING"',body)
    def test_cancelled_phase_cannot_admit_reverse_route_or_retreat(self):
        for path in ('addons/vehicles/functions/cortexVehicles.sqf',
                     'addons/vehicles/functions/cortexVehicleReverseStep.sqf',
                     'addons/infantry/functions/cortexGroupMove.sqf'):
            text=(ROOT/path).read_text(encoding='utf-8')
            self.assertIn('getOrDefault ["phase",""]) != "CANCELLED"',text)
if __name__=='__main__': unittest.main()
