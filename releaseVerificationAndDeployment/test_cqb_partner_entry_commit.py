"""Partner fallback command admission; no native path or physical entry is simulated."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class PartnerEntryCommitTests(unittest.TestCase):
    def test_late_entry_proposal_rechecks_episode_and_actor_at_atomic_mutation(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        section=source.split('private _entryAlternativeBefore=',1)[1].split('_entryRecovery set [_key,_receipt]',1)[0]
        atomic=section.split('isNil {',1)[1]
        mutation=atomic.index('_partner setVariable ["CBE_Cortex_ClearEntryAlternative"')
        for guard in ('call _mayIssueMovement','call _actorAvailable','call _actorTaskFree',
                      'CortexZeusHeld','serverTime <= (_job get "deadline")',
                      'serverTime <= (_job get "hardDeadline")','isEqualTo _entryAlternativeBefore',
                      'isEqualTo _entryNative','call _ownsCurrentMove','vectorDistance _pose <= 1'):
            self.assertLess(atomic.index(guard),mutation)
        self.assertLess(mutation,atomic.index('_partner doMove _alternative'))
        self.assertLess(atomic.index('_partner doMove _alternative'),atomic.index('call _rememberMove'))
        self.assertNotIn('serverTime+',atomic)
        self.assertNotIn('setPos',atomic)
        self.assertNotIn('setVelocity',atomic)
        self.assertIn('formLeader _partner',atomic)
        self.assertNotIn('formationLeader _partner',source)
    def test_geometry_and_ownership_remain_distinct(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        section=source.split('private _entryAlternativeBefore=',1)[1].split('_entryRecovery set [_key,_receipt]',1)[0]
        self.assertLess(section.index('_alternatives sort true'),section.index('isNil {'))
        self.assertIn('forEach (_cleared select [0,24])',section)
        gate=source.split('private _mayIssueMovement = {',1)[1].split('// Before exterior actors',1)[0]
        for guard in ('local _group','CBE_BuildingBrain','CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration',
                      'CortexExternalTakeover','getPosWorld _building','NativeOrderReceipt'):
            self.assertIn(guard,gate)


class PartnerEntrySpaceTests(unittest.TestCase):
    def test_alternate_entry_prefers_free_space_and_rechecks_before_consumption(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        section=text.split('private _entryAlternativeBefore=',1)[1].split('_entryRecovery set [_key,_receipt]',1)[0]
        self.assertLess(section.index('private _freeAlternatives='),section.index('_alternatives sort true'))
        self.assertIn('[[_partner]] call _occupiedRoomTargets',section)
        self.assertIn('if (_preferFreeEntry) then {_alternatives=_freeAlternatives}',section)
        commit=section.split('isNil {',1)[1]
        self.assertLess(commit.index('!_preferFreeEntry'),commit.index('_partner setVariable'))
        self.assertLess(commit.index('call _roomTargetOccupied'),commit.index('_partner doMove'))
        occupied=text.split('private _occupiedRoomTargets={',1)[1].split('private _roomTargetOccupied=',1)[0]
        self.assertIn('_occupied pushBack (getPosATL _actor)',occupied)
        self.assertIn('_workers select [0,8]',occupied)
        self.assertNotIn('nearEntities',occupied)


class PartnerProgressTargetTests(unittest.TestCase):
    def test_retarget_preserves_stall_clock_and_retry(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        block=text.split('if ((_receipt param [3,[]]) isNotEqualTo _entryTarget) then {',1)[1].split('} else {',1)[0]
        self.assertIn('_receipt set [0,_distance]',block)
        self.assertIn('_receipt set [3,+_entryTarget]',block)
        self.assertNotIn('set [1,',block)
        self.assertNotIn('set [2,',block)
        section=text.split('// Partner entry recovery is independent',1)[1].split('// Persist retirement',1)[0]
        self.assertIn('private _receipt=+(',section)
        self.assertIn('_receipt set [3,+_alternative]',section)
        self.assertIn('[_distance,_now,false,+_entryTarget]',section)
        self.assertIn('_receipt set [4,+_entryPosition]',block)
        motion=section.split('private _entryPosition=',1)[1].split('if (!(_receipt select 2)',1)[0]
        self.assertIn('_entryPosition vectorDistance _entryMotionAnchor >= 1',motion)
        self.assertIn('[_partner] call _ownsCurrentMove',motion)
        self.assertIn('simulationEnabled _partner',motion)
        self.assertIn('!isObjectHidden _partner',motion)
        self.assertIn('|| {_entryMoved}',motion)
        self.assertNotIn('hardDeadline',motion)
        self.assertNotIn('doMove',motion)
        self.assertNotIn('_receipt set [2,',motion)
