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
    def test_geometry_and_ownership_remain_distinct(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        section=source.split('private _entryAlternativeBefore=',1)[1].split('_entryRecovery set [_key,_receipt]',1)[0]
        self.assertLess(section.index('_alternatives sort true'),section.index('isNil {'))
        self.assertIn('forEach (_cleared select [0,24])',section)
        gate=source.split('private _mayIssueMovement = {',1)[1].split('// Before exterior actors',1)[0]
        for guard in ('local _group','CBE_BuildingBrain','CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration',
                      'CortexExternalTakeover','getPosWorld _building','NativeOrderReceipt'):
            self.assertIn(guard,gate)
