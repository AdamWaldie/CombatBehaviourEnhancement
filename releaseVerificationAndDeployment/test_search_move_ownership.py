"""Search issue/handback contracts: newer tasks must not inherit predecessor ownership."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/'addons/infantry/functions'/name).read_text(encoding='utf-8')
class SearchMoveOwnership(unittest.TestCase):
    def test_owned_move_requires_actual_destination_and_authored_route(self):
        text=source('cortexSearchMoveOwned.sqf')
        for proof in ('currentCommand _actor in ["MOVE","","STOP"]','_native vectorDistance _target <= 0.25',
                      'CBE_fnc_NativeOrderReceipt','CortexActorMoveReserved','CortexZeusHeld',
                      'CortexExternalTakeover','CBE_AIPass_ClearOrder','select [0,16]','fleeing _actor','ace_medical_ai_healQueue',
                      '_actor checkAIFeature "MOVE"','_actor checkAIFeature "PATH"'):
            self.assertIn(proof,text)
        for forbidden in ('doMove','doFollow','doStop','setVariable','serverTime+'):
            self.assertNotIn(forbidden,text)
    def test_receipts_follow_actual_atomic_issue_and_remain_bounded(self):
        text=source('cortexGroupTick.sqf')
        self.assertEqual(text.count('private _issuedSearch=[];'),2)
        for index,body in enumerate(text.split('private _issuedSearch=[];')[1:]):
            body=body.split('forEach (_team select [0,16]);',1)[0]
            for proof in ('isNil {','_searchEpoch ==','_searchRoute isEqualTo',
                          'CortexActorMoveReserved'):
                self.assertLess(body.index(proof),body.index('_searchActor doMove'))
            self.assertLess(body.index('_searchActor doMove'),body.index('_issuedSearch pushBack'))
            task='currentCommand _searchActor == ""' if index == 0 else '_searchCommand == "" || {_searchHold}'
            self.assertLess(body.index(task),body.index('_searchActor doMove'))
        calm=text.split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        known=calm.split('private _teamSearch=',1)[1]
        self.assertIn('if (!_teamSearch) then',known)
        self.assertIn('_team=_issuedSearch apply {_x select 0}',known)
        accepted=known.split('if (_searchAccepted) then {',2)[-1]
        for marker in ('"investigate", 120','"baseBehaviour"','"searchTeam"','"KNOWN_CONTACT"','CBE_AIPass_Investigations'):
            self.assertIn(marker,accepted)
        self.assertNotIn('currentCommand _searchActor in ["","STOP","FOLLOW"]',known)
        self.assertIn("_x glanceAt _target",known)
        investigation=text.split('case "INVESTIGATE": {',1)[1].split('case "CONTACT": {',1)[0]
        self.assertNotIn("doWatch",known+investigation)
        area=calm.split('private _areaWaypoint=',1)[1].split('if (!_ordered &&',1)[0]
        self.assertLess(area.index('(_areaWaypoint select 0) == _group'),area.index('"investigate",120'))

        self.assertIn('CBE_fnc_CortexSearchMoveOwned',text)
        security=text.split('case "SECURITY": {',1)[1].split('case "SEARCH": {',1)[0]
        for marker in ('formLeader _searchActor == _leader','call CBE_fnc_CortexHolderRecallOwned',
                       '_searchReceipt pushBack (_hold select [1,5])','_team=_issuedSearch apply',
                       '"NO_SEARCH_ISSUED"','CBE_Cortex_SearchHoldSerial'):
            self.assertIn(marker,security)
        self.assertLess(security.index('_team=_issuedSearch apply'),security.index('"SEARCH_TEAM_SENT"'))
        proof=source('cortexSearchMoveOwned.sqf')
        self.assertIn('count _x in [3,4]',proof)
        self.assertIn('count _row == 4',proof)
        self.assertIn('call CBE_fnc_CortexHolderRecallOwned',proof)
        self.assertIn('isNotEqualTo _token',proof)
        retire=source('cortexSearchHoldRelease.sqf')
        self.assertIn('count _x == 4',retire)
        self.assertIn('isEqualTo _token',retire)
        self.assertIn('select [0,16]',retire)
        for forbidden in ('doMove','doFollow','doStop','forceSpeed'):
            self.assertNotIn(forbidden,retire)
        self.assertEqual(text.count('call CBE_fnc_CortexSearchHoldRelease'),2)
        self.assertIn('call CBE_fnc_CortexSearchHoldRelease',source('cortexRestoreCalm.sqf'))

    def test_checkpoint_carries_receipts_and_calm_consumes_only_exact_search_move(self):
        self.assertIn('"searchMoveReceipts"',source('cortexCheckpoint.sqf'))
        text=source('cortexRestoreCalm.sqf')
        self.assertIn('private _recallOwned=if (_returnSearchTeam) then',text)
        self.assertIn('[_group,_state,_unit] call CBE_fnc_CortexSearchMoveOwned',text)
        self.assertIn('!_yieldToExternal && {_recallOwned}',text)
        self.assertIn('"searchTeam", "searchMoveReceipts",',text)
    def test_handback_checks_and_native_recall_share_atomic_scope(self):
        calm=source('cortexRestoreCalm.sqf').split('private _releaseOwnedHold={',1)[1].split('private _supportHeld=',1)[0]
        self.assertLess(calm.index('isNil {'),calm.index('CBE_fnc_CortexSearchMoveOwned'))
        self.assertLess(calm.index('CBE_fnc_CortexSearchMoveOwned'),calm.index('_unit doFollow _leader'))
        self.assertIn('private _leader=[_group] call CBE_fnc_CortexGroupAnchor',calm)
        self.assertIn('!isNull _leader',calm)
        tick=source('cortexGroupTick.sqf')
        contact=tick.split('private _beginContact = {',1)[1].split('call _enterContact;',1)[0]
        self.assertLess(contact.index('isNil {'),contact.index('CBE_fnc_CortexSearchMoveOwned'))
        self.assertIn('_leader == leader _group',contact)
        self.assertIn('isEqualTo _state',contact)
if __name__=='__main__': unittest.main()
