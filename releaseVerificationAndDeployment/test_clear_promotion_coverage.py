"""Protect established exit cover during casualty promotion; physical flow unverified."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearPromotionCoverageTests(unittest.TestCase):
    def test_settled_observer_requires_current_physical_substitute(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        gate=s.split('private _mayPromoteReserve=',1)[1].split('private _pairRosterChanged=',1)[0]
        for marker in ('_observer != _candidate','call _reserveReady','isEqualTo _exit',
                       'CBE_Cortex_ClearExitWatchLocal','vectorDistance (AGLToASL _post) <= 2',
                       '<= 0.75','terrainIntersectASL','"VIEW","NONE"'):
            self.assertIn(marker,gate)
        self.assertIn('if ((_stage param [2,""]) != "ARRIVED") exitWith {',gate)
        self.assertIn('_promotionProofs set [netId _candidate,_proof];true',gate)
        self.assertIn('_promotionViewBudget=_promotionViewBudget-1',gate)
        self.assertIn('if (_promotionViewBudget <= 0) exitWith {false}',gate)
        self.assertEqual(gate.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('hardDeadline',gate)
    def test_no_candidate_never_falls_through_to_last_reserve(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _replacementIndex=-1',s)
        selection=s.split('private _replacementIndex=-1;',1)[1].split('// Keep the casualty slot pending',1)[0]
        self.assertLess(selection.index('_replacementRanks sort true'),selection.index('call _mayPromoteReserve'))
        self.assertIn('if (_mayPromote) exitWith',selection)
        self.assertIn('netId _x,_x',selection)
        self.assertIn('_promotionViewBudget < _viewBefore',selection)
        self.assertIn('_lastProbeIndex+1',selection)
        self.assertIn('_promotionProbeLast deleteAt _probeKey',selection)
        self.assertIn('(_promotionCandidates select {_x in _reserves})',selection)
        self.assertIn('_replacementRanks apply {_x select 2},2,1,_receiving] call CBE_fnc_CombatElementSelect',selection)
        self.assertIn('if (_reinforceAnchor isEqualTo _buddy) then {[_buddy]} else {[]}',selection)
        self.assertIn('_preferredRanks+(_replacementRanks select {!((_x select 2) in _preferred)})',selection)
        self.assertLess(selection.index('call CBE_fnc_CombatElementSelect'),selection.index('_lastProbeIndex+1'))
        self.assertLess(selection.index('_lastProbeIndex+1'),selection.index('call _mayPromoteReserve'))
        for forbidden in ('setVariable ["CBE_CombatPairs"','doMove','set ["hardDeadline"','set ["deadline"'):
            self.assertNotIn(forbidden,selection)
        # Start nearest, then rotate after actual failed probes to reach a farther viable post.
        candidates=[(30,0,'far'),(4,1,'near'),(4,2,'tie')]
        ranked=sorted(candidates)
        self.assertEqual([row[2] for row in ranked],['near','tie','far'])
        seen=[];last=None
        for _ in range(3):
            offset=next((i+1 for i,row in enumerate(ranked) if row[2]==last),0)
            ordered=ranked[offset:]+ranked[:offset]
            last=ordered[0][2];seen.append(last)
        self.assertEqual(seen,['near','tie','far'])
        self.assertIn('[_candidate] call _mayPromoteReserve',s)
        guard=s.index('if (_replacementIndex < 0) then {')
        refusal=s[guard:s.index('private _replacement=_reserves select _replacementIndex')]
        self.assertIn('call _requestExitRelief',refusal)
        self.assertIn('continue',refusal)
        self.assertLess(guard,s.index('private _replacement=_reserves select _replacementIndex'))
        self.assertIn('private _promotionViewBudget=1',s)
        self.assertIn('promotionCandidateCursor',s)
        self.assertIn('!(_candidate in _reserves)',s)
        window=s.split('// Window the full roster',1)[1].split('private _promotionProofs=',1)[0]
        self.assertIn('(_candidateCount min 16)-1',window)
        self.assertIn('(_observerCount min 24)-1',window)
        self.assertIn('(_cursor+_offset) mod _candidateCount',window)
        self.assertIn('(_cursor+1) mod _candidateCount',window)
        self.assertNotIn('_reserves select [0,16]',window)
        # Independent bounded-roster model: every late candidate/observer can be reached.
        for count,limit in ((40,16),(48,24),(8,16),(1,24)):
            seen=set()
            for cursor in range(count):
                batch=[(cursor+offset)%count for offset in range(min(count,limit))]
                self.assertLessEqual(len(batch),limit)
                self.assertEqual(len(batch),len(set(batch)))
                seen.update(batch)
            self.assertEqual(seen,set(range(count)))

        self.assertIn('_replacementIndex=_reserves find _candidate',s)
    def test_two_simultaneous_losses_cannot_spend_both_duplicate_observers(self):
        reserves=['a','b'];posts={'a':'exit','b':'exit'}
        def can_promote(candidate):
            return any(other!=candidate and posts[other]==posts[candidate] for other in reserves)
        self.assertTrue(can_promote('a'))
        reserves.remove('a')
        self.assertFalse(can_promote('b'))
    def test_early_exit_worker_can_supply_current_cover_without_becoming_a_reserve(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        pool=s.split('private _promotionObservers=',1)[1].split('private _pairRosterChanged=',1)[0]
        for marker in ('keys _earlyExits select [0,8]', 'pushBackUnique',
                       'promotionObserverCursor', 'forEach _promotionObservers',
                       '_earlyExits getOrDefault [netId _observer,[]]',
                       '(_row param [0,objNull]) == _observer',
                       '(_row param [3,""]) == "ARRIVED"',
                       '[_observer] call _actorAvailable', '[_observer] call _actorTaskFree',
                       '!(_observer in _unavailable)'):
            self.assertIn(marker,pool)
        self.assertEqual(pool.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('doMove',pool)
        self.assertNotIn('doFollow',pool)
        self.assertNotIn('hardDeadline',pool)

class ClearReserveAdmissionTests(unittest.TestCase):
    def test_delayed_reserve_uses_episode_admission_not_first_stage_baseline(self):
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        block=admission.split('// Bind delayed reserve admission',1)[1].split('private _actorVisits=',1)[0]
        self.assertIn('if (!_resume) then',block)
        capture=admission.split('// Capture admitted native intent',1)[1].split('// Suppress only competing',1)[0]
        self.assertIn('_available select [0,64]',capture)
        self.assertIn('formLeader _x',capture)
        self.assertIn('if (!_resume) then',capture)
        self.assertIn('_reserveAdmissionRows',block)
        self.assertIn('(_reserveAdmission select 0) isEqualTo _visitContext',block)
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        gate=step.split('private _reserveReady=',1)[1].split('private _reserves=',1)[0]
        self.assertNotIn('private _stageCommandFree=!_stagedHere',gate)
        self.assertIn('_command == "" || {[_candidate] call _ownsCurrentMove}',gate)
        self.assertIn('_stagedHere} && {_command == "STOP"}',gate)
        self.assertIn('vectorDistance (AGLToASL _post) <= 2',gate)
        self.assertIn('call _ownsCurrentMove',gate)
        self.assertIn('(_admitted select 1) == _command',gate)
        self.assertIn('_native isEqualTo _original',gate)
        self.assertIn('formLeader _candidate == (_admitted select 3)',gate)
        self.assertNotIn('doMove',gate)
        self.assertNotIn('setVariable',gate)
        self.assertIn('[_reserves select _replacementIndex] call _reserveReady',step)

    def test_reserve_admission_retires_on_terminal_or_explicit_release(self):
        for name in ('buildingOperationStep.sqf','cortexClearRelease.sqf'):
            source=(ROOT/'addons/infantry/functions'/name).read_text()
            self.assertIn('setVariable ["CBE_Cortex_ClearReserveAdmission",nil,true]',source)

class ClearReplacementEntryTests(unittest.TestCase):
    def test_historical_entry_needs_a_live_original_interior_survivor(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        handoff=source.split('if (_laneRosterChanged) then {',1)[1].split('} forEach _pairs;',1)[0]
        first=handoff.split('private _survivorIndex=',1)[1].split('if (_survivorIndex < 0)',1)[0]
        for guard in ('_x in _enteredActors','!(_x in _laneReplacements)',
                      '[_x] call _actorAvailable','!(_x in _unavailable)',
                      '!(netId _x in _earlyExits)'):
            self.assertIn(guard,first)
        self.assertIn('_state set [12,false]',handoff)
        self.assertIn('_state set [0,0]',handoff)
        self.assertNotIn('pushBackUnique _replacement',handoff)
        self.assertNotIn('set ["deadline"',handoff)
        self.assertNotIn('set ["hardDeadline"',handoff)
        self.assertNotIn('doMove',handoff)

class ExteriorPromotionFacingTests(unittest.TestCase):
    def test_alternate_cover_faces_watch_before_spending_geometry_budget(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        gate=source.split('private _mayPromoteReserve=',1)[1].split('private _pairRosterChanged=',1)[0]
        facing='getDir _observer-(_observer getDir _watch)'
        self.assertIn(facing,gate)
        self.assertLess(gate.index(facing),gate.index('_promotionViewBudget=_promotionViewBudget-1'))
        self.assertIn('mod 360)-180) <= 75',gate)
        self.assertEqual(gate.count('lineIntersectsSurfaces'),1)
        garrison=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        alternate=garrison.split('_spare=_living findIf',1)[1].split('} >= 0;',1)[0]
        self.assertIn('getDir _x-(_x getDir _watch)',alternate)
        self.assertLess(alternate.index('getDir _x-(_x getDir _watch)'),alternate.index('call CBE_fnc_CortexGarrisonArrived'))
        arrival=(ROOT/'addons/infantry/functions/cortexGarrisonArrived.sqf').read_text()
        self.assertNotIn('getDir _actor',arrival)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('_heading > 75',audit)

if __name__=='__main__':unittest.main()
