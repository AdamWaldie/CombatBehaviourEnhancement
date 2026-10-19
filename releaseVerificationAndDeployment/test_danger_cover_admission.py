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
if __name__=='__main__':unittest.main()