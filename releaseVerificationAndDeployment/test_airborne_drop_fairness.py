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

    def test_mixed_crew_handover_forms_only_original_landed_cargo(self):
        helper=(ROOT/'addons/aircraft/functions/cortexAirborneGroundHandover.sqf').read_text()
        step=(ROOT/'addons/aircraft/functions/cortexAirborneDropStep.sqf').read_text()
        config=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        self.assertIn('class CortexAirborneGroundHandover',config)
        self.assertIn('[_job] call CBE_fnc_CortexAirborneGroundHandover',step)
        self.assertIn('"DEFERRED" && {time < (_job get "deadline")}',step)
        self.assertIn('&& {_groundHandoverOK}',step)
        before=helper.split('private _ground=createGroup',1)[0]
        for marker in ('CBE_AIPass_DropEpisode','CBE_AIPass_Epoch','count _roster > 64',
                       'group _x == _group','!isTouchingGround _x','!local _x',
                       'CortexActorMoveReserved','IndoorActorGroupAvailable','ace_medical_ai_healQueue',
                       'CBE_ParachuteDeploy','CBE_fnc_CortexIsPaused',
                       'CBE_Danger_EngineStanceLease','CBE_Danger_AttackPace','CBE_Cortex_StanceReceipt'):
            self.assertIn(marker,before)
        self.assertLess(helper.index('_job set ["groundHandover",_result]'),helper.index('_cargo joinSilent _ground'))
        self.assertLess(helper.index('private _cargoNative='),helper.index('private _ground=createGroup'))
        commit=helper.split('// GroupCreated mission handlers',1)[1].split('_cargo joinSilent _ground;',1)[0]
        for proof in ('_cargoNative findIf','currentCommand _actor != _command',
                      '(expectedDestination _actor) isNotEqualTo _destination','formLeader _actor != _leader'):
            self.assertIn(proof,commit)
        self.assertIn('private _joined=_cargo select {group _x == _ground}',helper)
        self.assertIn('currentCommand _x in ["STOP","GET IN"',before)
        after_join=helper.split('_cargo joinSilent _ground;',1)[1]
        self.assertLess(after_join.index('currentCommand _x == "STOP"'),after_join.index('_ground addWaypoint'))
        self.assertIn('_alive findIf {toUpperANSI currentCommand _x == "STOP"} < 0',step)
        mission_route=helper.split('if (count waypoints _ground > 1) then {',1)[1].split('} else {',1)[0]
        self.assertIn('count _joined == count _cargo',mission_route)
        self.assertIn('"HANDED_OVER"',mission_route)
        self.assertNotIn('addWaypoint',mission_route)
        self.assertNotIn('setCurrentWaypoint',mission_route)
        self.assertIn('in ["NOT_REQUIRED","ASSIGNED","HANDED_OVER"]',step)
        self.assertIn('isNil {_ground getVariable _x}',helper)
        native_policy=helper.split('if (count waypoints _ground <= 1) then {',1)[1].split('// GroupCreated mission handlers',1)[0]
        self.assertIn('_ground setCombatMode (combatMode _group)',native_policy)
        self.assertIn('count _joined == count _cargo',helper)
        self.assertIn('[_ground,true] call CBE_fnc_GroupBrainStart',helper)
        self.assertIn('(units _ground) findIf {!(_x in _joined)} < 0',helper)
        self.assertIn('units _ground isNotEqualTo []',helper)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAirborne.sqf').read_text()
        self.assertIn('AIRBORNE-mixed-real-ground-squad',qa)
        self.assertIn('AIRBORNE-mixed-crew-route-preserved',qa)
        self.assertIn('AIRBORNE-mixed-ground-brain',qa)
        self.assertIn('if (_grouped) then {_cargo=_ground}',qa)
        self.assertIn('_ground addWaypoint',helper)
        self.assertIn('_target=(_target select [0,2])+[0]',helper)
        self.assertIn('((_job get "target") select [0,2])+[0]',step)
        self.assertNotIn('_group addWaypoint',helper)
        for forbidden in ('setPos','moveIn','setSkill','reveal ','joinSilent _group','spawn','while {'):
            self.assertNotIn(forbidden,helper)
        roster={'cargo-a','cargo-b','dead-cargo','departed'}
        current={'cargo-a','cargo-b','dead-cargo','pilot','gunner','late-arrival'}
        living=current-{'dead-cargo'}
        joined=roster & living & current
        self.assertEqual(joined,{'cargo-a','cargo-b'})
        self.assertEqual(current-joined,{'dead-cargo','pilot','gunner','late-arrival'})
        self.assertNotEqual(len(joined-{'cargo-b'}),len(joined)) # Partial join cannot count as full.

    def test_attempt_advances_before_exit_and_only_acceptance_refreshes_hold(self):
        text=(ROOT/'addons/aircraft/functions/cortexAirborneDropStep.sqf').read_text()
        attempt=text.split('private _jumper=_jumpers select 0;',1)[1].split('// LAND',1)[0]
        self.assertLess(attempt.index('_job set ["index"'),attempt.index('call CBE_fnc_CortexParachuteJump'))
        self.assertIn('_job set ["lastExit",[_jumper,_accepted,time]]',attempt)
        self.assertIn('if (_accepted) then {_aircraft setVariable',attempt)
        self.assertNotIn('while {',attempt)
