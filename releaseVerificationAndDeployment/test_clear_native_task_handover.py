"""Authored tasks retain native semantics when an owned clearance leg is released."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearNativeTaskHandoverTests(unittest.TestCase):
    def test_non_move_leader_releases_native_formation_without_fabricated_route(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        handback=s.split('if (_reason == "NEW_ORDER" && {local _group}',1)[1].split('forEach _handbacks;',1)[0]
        for guard in ('local _group','CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration',
                      'currentCommand _actor == _command','_destination vectorDistance _target <= 0.25',
                      'call _actorAvailable','call _actorTaskFree','CortexExternalTakeover',
                      'call CBE_fnc_NativeOrderReceipt','count (_group getVariable ["CBE_Operation"'):
            self.assertIn(guard,handback)
        # The native return now covers leaders for MOVE as well as non-MOVE tasks,
        # preserving attachments/scripts instead of flattening MOVE to one position.
        self.assertIn('_actor doFollow leader _group;',handback)
        self.assertNotIn('if (_actor == leader _group)',handback)
        self.assertNotIn('doMove',handback)
        self.assertNotIn('waypointPosition',handback)
        for forbidden in ('addWaypoint','deleteWaypoint','setCurrentWaypoint','joinSilent','enableAI'):
            self.assertNotIn(forbidden,handback)
