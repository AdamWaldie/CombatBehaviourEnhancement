"""Unresolved native-shot safety contracts. Physical engine behavior remains audit-only."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SUPPORT = ROOT / 'addons' / 'support' / 'functions'


class SupportUncertainty(unittest.TestCase):
    def test_timeout_parks_without_releasing_or_reissuing_native_command(self):
        text = (SUPPORT / 'cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        gate = text.split('if ((_mission get "phase") in ["PENDING", "UNCERTAIN"]', 1)[1]
        parked = gate.split('private _requester=', 1)[0]
        self.assertIn('time > (_mission get "deadline")', parked)
        self.assertIn('_mission set ["parked",true]', parked)
        self.assertIn('_mission set ["remaining",0]', parked)
        self.assertIn('_mission set ["burstsLeft",0]', parked)
        for forbidden in ('call _finish', 'deleteAt', 'remoteExec', 'doArtilleryFire', 'commandArtilleryFire'):
            self.assertNotIn(forbidden, parked)
        self.assertNotIn('_mission set ["deadline", time + 900]', text)
        step = (SUPPORT / 'artilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('UNCERTAINTY_PARKED', step)
        self.assertIn('_semantic="QUARANTINED"', step)

    def test_qualified_replies_wake_settlement_without_firing(self):
        for name in ('cortexArtilleryFired', 'cortexArtilleryRejected'):
            text = (SUPPORT / (name + '.sqf')).read_text(encoding='utf-8')
            before, wake = text.split('if (_mission getOrDefault ["parked",false]) then {', 1)
            self.assertIn('exitWith {}', before)
            self.assertIn('_mission set ["phase", "WAIT"]', before)
            self.assertIn('_mission set ["parked",false]', wake)
            self.assertIn('call WAIT_fnc_ArtilleryMissionStart', wake)
            self.assertNotIn('ArtilleryShot', wake)
            self.assertNotIn('doArtilleryFire', wake)
        fired = (SUPPORT / 'cortexArtilleryFired.sqf').read_text(encoding='utf-8')
        self.assertIn('_ammo != getText', fired)
        self.assertIn('_position distance2D (_mission get "aim") > 10', fired)
        rejected = (SUPPORT / 'cortexArtilleryRejected.sqf').read_text(encoding='utf-8')
        self.assertIn('(_mission get "token") != _token', rejected)
        self.assertIn('call WAIT_fnc_HeadlessResolveSender', rejected)

    def test_deletion_cleanup_is_exact_and_repeat_safe(self):
        text = (SUPPORT / 'artilleryMissionStart.sqf').read_text(encoding='utf-8')
        deletion = text.split('if (isNil {missionNamespace getVariable "WAIT_Artillery_DeletedEH"}) then {', 1)[1]
        deletion = deletion.split('private _current=', 1)[0]
        self.assertIn('(_record getOrDefault ["battery",objNull]) isEqualTo _entity', deletion)
        self.assertIn('_missions deleteAt _key', deletion)
        self.assertNotIn('forEach', deletion)
        self.assertNotIn('allUnits', deletion)
        stop = (ROOT / 'addons/core/functions/cortexStop.sqf').read_text(encoding='utf-8')
        self.assertIn('removeMissionEventHandler ["EntityDeleted",_artilleryDeletedEH]', stop)
        self.assertIn('missionNamespace setVariable ["WAIT_Artillery_DeletedEH",nil]', stop)


if __name__ == '__main__':
    unittest.main()
