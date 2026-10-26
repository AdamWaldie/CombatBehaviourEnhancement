"""Earlier observation is not speed, clearance or measured latency acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class DrivingAnticipationCadence(unittest.TestCase):
    def test_hint_reuses_current_lane_and_crossing_observation_without_new_scan(self):
        s=source('drivingFollowingCap')
        self.assertEqual(s.count('nearEntities'),1)
        self.assertIn('count _candidates > 64',s)
        lane=s.split('if (_ahead && {_sameLane} && {_sameHeight})',1)[1]
        self.assertIn('if (_hullGap <= _watchRoom && {!_following || {_ownForward-_otherForward > 0.5}}) then {_nearConflict=true}',lane)
        self.assertIn('if (_fromRight || {_room <= _stoppingRoom}) then {_nearConflict=true}',s)
        self.assertIn('[_cap,_limiting,_gap,time,count _candidates,_nearConflict]',s)
        self.assertIn('private _reaction=4;',s)
        for forbidden in ('forceSpeed','doMove','setVariable'):
            self.assertNotIn(forbidden,s)
    def test_hint_survives_cap_row_override_and_both_existing_clocks_consume_it(self):
        start=source('drivingAssistStart')
        self.assertLess(start.index('private _trafficWatch=(_traffic param [5,false,[true]])'),start.index('if (_rearPathRejected) then {_traffic='))
        self.assertIn('_routeIdentity,_reverseIssued,_trafficWatch]]',start)
        self.assertIn('select (_trafficLimited || {_trafficWatch} || {_corridorActive}',start)
        step=source('drivingOperationStep')
        owner=step.split('if ((_state param [3,grpNull]) == _group)',1)[1]
        self.assertIn('_watchTraffic=_watchTraffic || {_state param [11,false,[true]]}',owner)
        self.assertIn('select (_crewPending || {_traffic} || {_watchTraffic}',step)
        phase=step.split('if (_owned > 0) then',1)[1].split('_brain set ["phase"',1)[0]
        self.assertNotIn('_watchTraffic',phase)
        self.assertIn('setVariable ["CBE_DrivingAssist_State",nil]',source('drivingAssistRelease'))
if __name__=='__main__': unittest.main()
