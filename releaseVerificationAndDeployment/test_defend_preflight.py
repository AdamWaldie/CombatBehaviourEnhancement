"""Defence refusal must precede destructive task replacement; offline contracts only."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DefendPreflightTests(unittest.TestCase):
    def test_complete_layout_is_validated_before_releasing_or_writing(self):
        s=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        gate=s.index('if (!_layoutValid')
        self.assertLess(gate,s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(gate,s.index('setVariable ["WAIT_AIPass_DefendPos"'))
        self.assertIn('count _placements != count _units',s)
        for required in ('!finite _width','count _units > 64','!surfaceIsWater _position','distance2D _position < 1','_layoutValid=false','CortexExternalTakeover'):
            self.assertIn(required,s)
        self.assertIn('[_slot, _threat, 8, _taken, _group] call WAIT_fnc_CortexFindCover',s)
    def test_planning_context_is_read_only_and_rechecked_before_cleanup(self):
        s=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        capture=s.index('private _admissionRoute=')
        self.assertLess(capture,s.index('call WAIT_fnc_CortexFindCover'))
        guard=s.split('private _admissionCurrent={',1)[1].split('private _reserveCount',1)[0]
        for value in ('WAIT_AIPass_Epoch','call WAIT_fnc_NativeOrderReceipt','_admissionGenerations',
                      'currentCommand _actor != _command','isNotEqualTo _destination',
                      'group _actor != _group','vehicle _actor != _actor','CortexActorMoveReserved',
                      'formLeader _actor != _followLeader'):
            self.assertIn(value,guard)
        self.assertNotIn('setVariable',guard)
        final=s.index('if (!_layoutValid')
        self.assertIn('!(call _admissionCurrent)',s[final:s.index('// End transient movement')])
        self.assertLess(final,s.index('call WAIT_fnc_CortexReleaseGroup'))
        allocation=s.split('private _units =',1)[1].split('private _admissionRoute=',1)[0]
        self.assertIn('call WAIT_fnc_CortexActorMoveReserved',allocation)

    def test_reserve_plan_preserves_busy_actors_and_rejects_collapsed_slots(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendStep.sqf').read_text()
        available=s.split('private _reserveAvailable={',1)[1].split('private _reserve =',1)[0]
        for guard in ('CortexActorMoveReserved','isNull objectParent _actor','isNull remoteControlled _actor',
                      'currentCommand _actor in ["","STOP"]','WAIT_AIPass_DefendHolding'):
            self.assertIn(guard,available)
        publication=s.index('setVariable ["WAIT_AIPass_DefendPos"')
        self.assertLess(s.index('_taken findIf {_x distance2D _position < 1}'),publication)
        self.assertLess(s.index('if (!_layoutValid'),publication)
        self.assertLess(s.index('_reserve findIf {!([_x] call _reserveAvailable)}'),publication)
        self.assertLess(publication,s.index('_state set ["reserveCommitted", true]'))

    def test_delayed_defence_cannot_reissue_over_a_new_native_command(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendApplyLocal.sqf').read_text()
        receipt=s.split('private _ownsRouteCommand={',1)[1].split('[{',1)[0]
        for value in ('_command == "MOVE"','vectorDistance ((_route select 5) select 0) <= 0.25',
                      '_command == (_route select 7)','formLeader _actor == (_route select 9)',
                      '_destination isEqualTo (_route select 8)'):
            self.assertIn(value,receipt)
        retirement=s.split('// The current order belongs to somebody else.',1)[1].split('private _canIssue=',1)[0]
        self.assertIn('_routeCurrent=false',retirement)
        for command in ('doMove','doStop','doFollow','doWatch'):
            self.assertNotIn(command,retirement)
        self.assertLess(s.index('call _ownsRouteCommand)'),s.index('doStop _unit'))
        self.assertIn('_assignment isEqualTo ((_routes select _routeIndex) select 5)',s)
        self.assertEqual(s.count('_route set [6,true]'),2)

if __name__=='__main__': unittest.main()
