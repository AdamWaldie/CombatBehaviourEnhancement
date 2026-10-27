"""Actor command-boundary contracts; no physical launcher acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AntiArmourActorAuthorityTests(unittest.TestCase):
    def test_selection_and_commands_recheck_actor_authority(self):
        s=(ROOT/'addons/infantry/functions/cortexAntiArmour.sqf').read_text()
        predicate=s.split('private _actorAvailable={',1)[1].split('private _now =',1)[0]
        for guard in ('isPlayer _actor','remoteControlled _actor','CBE_fnc_CortexExternalOwner',
                      'CBE_fnc_CompatibilityExternalControl','simulationEnabled _actor','isObjectHidden _actor',
                      '"HEAL"','"GET IN"','"ACTION"'):
            self.assertIn(guard,predicate)
        self.assertIn('([_x] call _actorAvailable)',s)
        relocation=s.split('if (_blocked) exitWith {',1)[1]
        self.assertLess(relocation.index('call CBE_fnc_CortexFindCover'),relocation.index('if (!call _mayRelocate'))
        self.assertLess(relocation.index('if (!call _mayRelocate'),relocation.index('call CBE_fnc_LauncherMove'))
        fire=s.split('call CBE_fnc_LauncherMove',1)[1]
        self.assertLess(fire.index('if !([_gunner] call _actorAvailable)'),fire.index('_gunner doTarget'))
        self.assertIn('_command in ["","MOVE"]',s)
        executor=(ROOT/'addons/infantry/functions/launcherMove.sqf').read_text()
        for guard in ('local _actor','local _group','CortexExternalOwner','CortexExternalTakeover',
                      'CortexZeusHeld','ace_medical_ai_healQueue','CortexActorMoveReserved',
                      '_context isNotEqualTo _currentContext','_native isNotEqualTo _before'):
            self.assertLess(executor.index(guard),executor.index('_actor doMove'))
        self.assertIn('isNil {',executor)


    def test_relocation_preserves_new_individual_move_and_gated_routes(self):
        s=(ROOT/'addons/infantry/functions/cortexAntiArmour.sqf').read_text()
        guard=s.split('private _mayRelocate={',1)[1].split('if (_blocked && {!call _mayRelocate})',1)[0]
        for check in ('_index > 0','waypointType _waypoint != "MOVE"','waypointScript',
                      'waypointStatements','waypointTimeout','synchronizedWaypoints','synchronizedTriggers',
                      '!isNull waypointAttachedObject','!isNull waypointAttachedVehicle',
                      '_destination vectorDistance waypointPosition _waypoint <= 3'):
            self.assertIn(check,guard)
        movement=s.split('call CBE_fnc_CortexFindCover',1)[1].split('call CBE_fnc_LauncherMove',1)[0]
        self.assertIn('!call _mayRelocate',movement)
        self.assertIn('isNotEqualTo _relocationRoute',movement)
        self.assertLess(s.index('if (_blocked) exitWith {'),s.index('private _relocationRoute='))
