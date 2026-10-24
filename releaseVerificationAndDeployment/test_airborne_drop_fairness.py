"""Airborne roster fairness contracts and selection model; no engine acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

def choose(roster,cursor,eligible):
    if not isinstance(cursor,int) or not 0<=cursor<len(roster):cursor=0
    ordered=roster[cursor:]+roster[:cursor]
    actor=next((actor for actor in ordered if actor in eligible),None)
    return (actor,(roster.index(actor)+1)%len(roster)) if actor is not None else (None,cursor)

class AirborneDropFairnessTests(unittest.TestCase):
    def test_refused_passenger_cannot_starve_followers(self):
        roster=['failed','second','third']
        cursor=0
        attempts=[]
        aboard=set(roster)
        for _ in range(4):
            actor,cursor=choose(roster,cursor,aboard)
            attempts.append(actor)
            if actor!='failed':aboard.remove(actor)
        self.assertEqual(attempts,['failed','second','third','failed'])

    def test_temporarily_unavailable_passenger_rejoins_rotation(self):
        roster=['reserved','ready','late']
        actor,cursor=choose(roster,0,{'ready'})
        self.assertEqual(actor,'ready')
        self.assertEqual(choose(roster,cursor,{'reserved','late'}),('late',0))
        self.assertEqual(choose(roster,0,{'reserved'}),('reserved',1))
        self.assertEqual(choose([],0,set()),(None,0))
        self.assertEqual(choose(roster,999,{'reserved'}),('reserved',1))

    def test_deadline_and_pending_roster_precede_empty_eligibility(self):
        text=(ROOT/'addons/aircraft/functions/cortexAirborneDropStep.sqf').read_text()
        drop=text.split('if ((_job get "phase") == "DROP") exitWith {',1)[1].split('// LAND',1)[0]
        self.assertLess(drop.index('time > (_job get "deadline")'),drop.index('if (_jumpers isEqualTo [])'))
        self.assertIn('if (_aboard isEqualTo [] || {!alive _aircraft})',drop)
        self.assertIn('if (_jumpers isEqualTo []) exitWith {1}',drop)
        self.assertIn('group _x == _group',drop)
        self.assertLess(drop.index('[group _pilot] call CBE_fnc_CortexExternalTakeover'),drop.index('if (_jumpers isEqualTo [])'))
        self.assertLess(drop.index('[_group] call CBE_fnc_CortexExternalTakeover'),drop.index('if (_jumpers isEqualTo [])'))
        self.assertNotIn('_job set ["deadline"',drop)
        landing=text.split('// LAND\n',1)[1]
        self.assertIn('_roster=_job get "jumpers"',landing)
        self.assertIn('_roster select {alive _x && {group _x == _group}}',landing)
        self.assertIn('findIf {!(_x in _alive)} < 0',landing)
        self.assertLess(landing.index('private _groundOrderScoped='),landing.index('_group addWaypoint'))
        self.assertIn('if (_groundOrderScoped &&',landing)
        # Two original passengers can land while the same-group pilot stays
        # aboard. That completes cargo tracking but cannot author a crew SAD.
        roster={'cargo-a','cargo-b'}
        current=roster|{'pilot'}
        grounded=set(roster)
        self.assertFalse(current<=grounded) # former whole-group landing gate
        def outcome(current,grounded):
            survivors=roster & current
            landed=bool(survivors) and survivors<=grounded
            return landed,landed and current<=survivors
        self.assertEqual(outcome(current,grounded),(True,False))
        self.assertEqual(outcome(roster,grounded),(True,True))
        self.assertEqual(outcome(roster|{'new-member'},grounded|{'new-member'}),(True,False))
        self.assertEqual(outcome(roster,{'cargo-a'}),(False,False))
        self.assertEqual(outcome(set(),grounded),(False,False))

    def test_attempt_advances_before_exit_and_only_acceptance_refreshes_hold(self):
        text=(ROOT/'addons/aircraft/functions/cortexAirborneDropStep.sqf').read_text()
        attempt=text.split('private _jumper=_jumpers select 0;',1)[1].split('// LAND',1)[0]
        self.assertLess(attempt.index('_job set ["index"'),attempt.index('call CBE_fnc_CortexParachuteJump'))
        self.assertIn('_job set ["lastExit",[_jumper,_accepted,time]]',attempt)
        self.assertIn('if (_accepted) then {_aircraft setVariable',attempt)
        self.assertNotIn('while {',attempt)
