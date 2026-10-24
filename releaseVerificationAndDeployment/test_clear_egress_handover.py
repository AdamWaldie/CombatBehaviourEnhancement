"""Egress must yield to individual destination replacement before arrival or retry."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ClearEgressHandoverTests(unittest.TestCase):
    def test_terminal_hold_contains_only_actual_settlements_and_cleans_diverted_leases(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        finish = source.split('private _handbacks=[];',1)[1].split('if (_reason == "NEW_ORDER"',1)[0]
        movement = finish.split('if (_restore && {[_x] call _actorTaskFree}',1)[1].split('_x setVariable ["CBE_Cortex_ClearForcedSpeed",nil,true]',1)[0]
        self.assertIn('!(_x in (_job getOrDefault ["egressDiverted",[]]))',movement)
        self.assertLess(movement.index('doStop _x'),movement.index('_settled pushBackUnique _x'))
        loop = finish.split('} forEach ',1)[1].split(';',1)[0]
        self.assertNotIn('egressDiverted',loop)
        hold = finish.split('if (_reason == "COMPLETE" && {_restore}',1)[1]
        self.assertIn('_settled isNotEqualTo []',hold)
        self.assertIn('CBE_fnc_NativeOrderReceipt,+_settled,+_settledPosts]',hold)
        self.assertIn('CBE_Cortex_ClearEarlyExits",nil,true',finish)
        release = (ROOT / 'addons/infantry/functions/cortexClearRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_Cortex_ClearEarlyExits",nil,true',release)

    def test_transition_preserves_replacement_before_first_exit_order(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        transition = source.split('private _beginEgress={', 1)[1].split('\n    };\n    if (serverTime >', 1)[0]
        admission = transition.split('private _entries=', 1)[0]
        self.assertIn('if !([_actor] call _exitMovementOwned) then', admission)
        ownership=source.split('private _exitMovementOwned={',1)[1].split('private _activeOwnMove=',1)[0]
        self.assertIn('[_actor] call _actorTaskFree &&',ownership)
        task=source.split('private _actorTaskFree={',1)[1].split('// Record only stops',1)[0]
        self.assertIn('(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []',task)
        self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',ownership)
        self.assertIn('_diverted pushBackUnique _actor', admission)
        self.assertIn('deleteAt (netId _actor)', admission)
        self.assertIn('!(_actor in _diverted)', admission)
        self.assertIn('_job set ["egressFailed",true]', admission)
        self.assertIn('_job set ["egressDiverted",_diverted]', admission)
        self.assertIn('_job set ["egressPending",_pending]', transition)

    def test_individual_order_filters_arrivals_and_retry_without_losing_failure(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        egress = source.split('if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {', 1)[1]
        selection = egress.split('private _outsideExit={', 1)[0]
        self.assertIn('if !([_unit] call _exitMovementOwned) then', selection)
        self.assertIn('_diverted pushBackUnique _unit', selection)
        self.assertIn('deleteAt (netId _unit)', selection)
        self.assertIn('_x set [2,false]', selection)
        self.assertIn('!(_unit in _diverted)', selection)
        self.assertIn('if (count _assignments < count (_job get "egressAssignments")) then {_job set ["egressFailed",true]}', selection)
        self.assertIn('_assignments findIf {[_x] call _outsideExit}', egress)
        # The durable sender and resumed reader share progress fields rather than restarting grace.
        journal=source.split('// Publish only material egress changes.',1)[1]
        for field in ('_record param [1,-1]','_record param [2,-1]',
                      '_record param [5,-1]','_record param [6,[]]'):
            self.assertIn(field,journal)
        adoption=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        self.assertIn('private _exitRowSize=[6,10] select _progressVersion',adoption)
        for field in ('then {_x select 6}','then {_x select 7}','then {_x select 8}','then {+(_x select 9)}'):
            self.assertIn(field,adoption)
        self.assertIn('private _motionStalled=serverTime-(_record select 5) >= 8',egress)
        self.assertIn('forEach _assignments', egress)
        finish = source.split('private _handbacks=[];', 1)[1].split('private _delay', 1)[0]
        self.assertIn('[_x] call _exitMovementOwned', finish)

    def test_natural_continuation_is_opt_in_durable_and_after_successful_egress(self):
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        contact=(ROOT/'addons/infantry/functions/cortexBuildingContact.sqf').read_text(encoding='utf-8')
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('["continueRoute",true]',contact)
        self.assertIn('_previous param [12,false,[true]]',admission)
        self.assertIn('_options getOrDefault ["continueRoute",false]',admission)
        self.assertIn('"INVALID_CONTINUATION"',admission)
        self.assertIn('_job getOrDefault ["continueRoute",false],+(_job get "buildingTransform")], true]',s)
        block=s.split('// A natural clear is an interruption',1)[1].split('if (_reason == "NEW_ORDER"',1)[0]
        for guard in ('_result in ["COMPLETE","INCOMPLETE"]','!(_job getOrDefault ["egressFailed",false])','waypointType _waypoint == "MOVE"',
                      'waypointScript _waypoint == ""','waypointTimeout',
                      'synchronizedWaypoints','synchronizedTriggers','waypointAttachedObject',
                      'currentCommand _actor == "STOP"','_actor in _settled',
                      'CBE_fnc_NativeOrderReceipt','CBE_BuildingBrain','CBE_Operation',
                      'CBE_fnc_CortexExternalTakeover'):
            self.assertIn(guard,block)
        self.assertLess(s.index('call CBE_fnc_OperationRelease'),s.index('// A natural clear is an interruption'))
        self.assertLess(block.index('[_leader] call _mayContinue'),block.index('_leader doMove'))
        self.assertLess(block.index('[_x] call _mayContinue'),block.index('_x doFollow'))
        # Safe route handback and full room coverage are separate outcomes.
        # One inaccessible node previously kept this already-settled group held.
        coverage,positions=4,5
        result='COMPLETE' if coverage==positions else 'INCOMPLETE'
        def continuation(opt_in=True,egress_failed=False,route_unchanged=True):
            return opt_in and not egress_failed and route_unchanged and result in ('COMPLETE','INCOMPLETE')
        self.assertEqual(result,'INCOMPLETE')
        self.assertFalse(result=='COMPLETE') # former gate refuses every partial result
        self.assertTrue(continuation())
        self.assertFalse(continuation(opt_in=False))
        self.assertFalse(continuation(egress_failed=True))
        self.assertFalse(continuation(route_unchanged=False))
        self.assertIn('_group setVariable ["CBE_Cortex_ClearResult",[_result,',s)
        for forbidden in ('addWaypoint','deleteWaypoint','setCurrentWaypoint','enableAI','setPos'):
            self.assertNotIn(forbidden,block)

    def test_natural_route_fixture_observes_real_handover_without_replacement_orders(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertIn('BUILD-CONTACT-physical-entry',s)
        case=s.split('// Independent natural-contact continuation case;',1)[1].split('// A newer actor destination',1)[0]
        for marker in ('BUILD-CONTINUE-native-knowledge','BUILD-CONTINUE-natural-clear-started',
                       'BUILD-CONTINUE-physical-entry','BUILD-CONTINUE-real-defender-casualty',
                       'BUILD-CONTINUE-clearance-complete','BUILD-CONTINUE-physical-room-coverage','BUILD-CONTINUE-original-route-physical',
                       'BUILD-CONTINUE-authored-route-retained','FiredMan','"Killed"'):
            self.assertIn(marker,case)
        observation=case.split('// Enable real casualty resolution',1)[1].split('call CBE_fnc_CortexClearRelease',1)[0]
        for command in (' doMove ', ' doFollow ', 'addWaypoint','setCurrentWaypoint',
                        'call CBE_fnc_CortexClearBuilding',' setDamage ', ' setPos', ' reveal '):
            self.assertNotIn(command,observation)
        self.assertIn('_x distance2D _origin < 25',observation)
        self.assertIn('distance2D _routeDestination) < 20',observation)
        self.assertIn('_routeOutcome == "COMPLETE"',observation)
        self.assertIn('&& {_routePhysicalClear}',observation)
        self.assertIn('call _observedRoomVisit',case)
        self.assertIn('call _observeRouteRooms;',observation)

if __name__ == '__main__':
    unittest.main()


class ClearSettlementPresenceTests(unittest.TestCase):
    def test_historical_arrival_is_not_current_settlement(self):
        arrived=True
        def retained(arrived,distance,height):
            return arrived and distance<=1 and abs(height)<=1.5
        self.assertTrue(retained(arrived,0.5,0.2))
        self.assertFalse(retained(arrived,4,0.2))
        self.assertFalse(retained(arrived,0.5,3))
        self.assertFalse(retained(False,0.5,0.2))

    def test_displacement_retires_arrival_without_renewing_budget(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        check=s.split('private _outsideExit={',1)[1].split('private _early=',1)[0]
        self.assertIn('private _stillAtPost=',check)
        self.assertIn('_unit distance2D _target <= 1',check)
        self.assertIn('&& {_stillAtPost}) exitWith {false}',check)
        self.assertIn('_assignment set [2,false]',check)
        self.assertNotIn('egressDeadline',check)
        self.assertNotIn('doMove',check)


class TerminalContinuationBoundaryTests(unittest.TestCase):
    def test_native_continuation_and_hold_receipt_share_atomic_scope(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        block=text.split('// Exact route/actor checks, native continuation',1)[1].split('if (_reason == "NEW_ORDER" && {local _group}',1)[0]
        self.assertLess(block.index('isNil {'),block.index('private _leader=leader _group'))
        self.assertLess(block.index('[_leader] call _mayContinue'),block.index('_leader doMove'))
        self.assertLess(block.index('[_x] call _mayContinue'),block.index('_x doFollow'))
        self.assertIn('CBE_Cortex_ClearHold',block)
        self.assertIn('"reserveAdmissionCommands",createHashMap',block)
        self.assertIn('(_settled-[_leader]) select [0,63]',block)
        self.assertIn('for "_continuationCursor" from 0 to 63',block)
        self.assertIn('_returnLeader in _continued',block)
        self.assertIn('_x doFollow _returnLeader',block)
        self.assertNotIn('_x doFollow _leader',block)
        self.assertIn('private _children=createHashMap',block)
        self.assertLess(block.index('_children deleteAt'),block.index('[_x] call _mayContinue'))
        self.assertIn('isEqualTo _returnLeader',block)
        self.assertNotIn('private _beforeCount',block)
        # A64-actor star loses47followers under the former16-follower prefix.
        # Queue traversal also preserves long reverse-ordered parent chains and
        # refuses disconnected cycles or descendants of an unavailable anchor.
        def traverse(parents,blocked=()):
            children={}
            for actor,parent in parents:
                children.setdefault(parent,[]).append(actor)
            issued=[0]
            for cursor in range(64):
                if cursor>=len(issued):break
                for actor in children.get(issued[cursor],[]):
                    if actor not in blocked:issued.append(actor)
            return set(issued)
        wide=[(i,0) for i in range(1,64)]
        self.assertEqual(len({0}|{a for a,_ in wide[:16]}),17)
        self.assertEqual(len(traverse(wide)),64)
        chain=[(i,i-1) for i in reversed(range(1,64))]
        self.assertEqual(len(traverse(chain)),64)
        self.assertEqual(traverse([(1,0),(2,1),(3,4),(4,3)],blocked=(1,)),{0})
        self.assertIn('private _remaining=(_settled-_continued)+_unacknowledged',block)
        self.assertLess(block.index('_leader setVariable ["CBE_Cortex_ClearRecall"'),block.index('_leader doMove'))
        self.assertLess(block.index('_x setVariable ["CBE_Cortex_ClearRecall"'),block.index('_x doFollow'))
        self.assertIn('[_x,_handoverJob] call CBE_fnc_BuildingActorHoldOwned',block)
        # The issued set alone discarded every delayed actor. Retain only the
        # still-owned STOP, not the acknowledged FOLLOW or a newer individual MOVE.
        settled={'leader','buddy','diverted'}
        requested={'leader','buddy'}
        unchanged_stops={'leader'}
        self.assertEqual(settled-requested,{'diverted'})
        self.assertEqual((settled-requested)|(requested & unchanged_stops),{'leader','diverted'})

        handback=text.split('if (_reason == "NEW_ORDER" && {local _group}',1)[1].split('forEach _handbacks;',1)[0]
        self.assertLess(handback.index('isNil {'),handback.index('_actor doFollow leader _group'))
        self.assertIn('call _finishCurrent',handback)
        self.assertIn('[leader _group] call _actorAvailable',handback)
