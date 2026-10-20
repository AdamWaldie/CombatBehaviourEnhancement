"""Admission contracts for danger cover; native movement remains an engine acceptance item."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DangerCoverAdmission(unittest.TestCase):
    def test_shared_reservation_gate_precedes_geometry_and_native_commit(self):
        s=(ROOT/'addons/infantry/functions/dangerCoverStep.sqf').read_text(encoding='utf-8')
        first=s.index('call CBE_fnc_CortexActorMoveReserved')
        self.assertLess(first,s.index('call CBE_fnc_CortexFindCover'))
        commit=s.split('if (_entryContext isNotEqualTo',1)[1].split('_actor doMove _spot',1)[0]
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',commit)
        self.assertNotIn('(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo []',s)
    def test_gate_retains_unknown_and_live_reservations_without_renewal(self):
        s=(ROOT/'addons/infantry/functions/cortexActorMoveReserved.sqf').read_text(encoding='utf-8')
        for part in ('count _lease == 3','finite (_lease select 2)','time >= (_lease select 2)','!_expired'):
            self.assertIn(part,s)
        self.assertNotIn('setVariable',s)
    def test_native_planning_is_not_mistaken_for_idle_cover_admission(self):
        s=(ROOT/'addons/infantry/functions/dangerCoverStep.sqf').read_text(encoding='utf-8')
        first=s.index('getUnitState _actor in ["INIT","PLANNING","REPLAN"]')
        self.assertLess(first,s.index('call CBE_fnc_CortexFindCover'))
        commit=s.split('if (_entryContext isNotEqualTo',1)[1].split('_actor doMove _spot',1)[0]
        self.assertIn('getUnitState _actor in ["INIT","PLANNING","REPLAN"]',commit)
        self.assertNotIn('setDestination',s)
    def test_indoor_dispatch_and_start_use_same_expiry_without_erasing_live_journals(self):
        dispatch=(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text(encoding='utf-8')
        start=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text(encoding='utf-8').split('if (_mode == "START") exitWith {',1)[1]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',dispatch)
        self.assertIn('[_actor] call CBE_fnc_CortexActorMoveReserved',start)
        self.assertLess(start.index('call CBE_fnc_CortexActorMoveReserved'),start.index('_actor setVariable ["CBE_Cortex_ActorMove"'))
        self.assertIn('CBE_IndoorActor_Order",[]]) isNotEqualTo []',start)
        self.assertIn('count (_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) > 0',start)
        self.assertIn('call CBE_fnc_IndoorActorNativeContext',start)
if __name__=='__main__':unittest.main()