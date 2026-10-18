"""Queue expiry/idempotence admission contracts; not native queue execution."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class DrivingQueueExpiry(unittest.TestCase):
    def test_server_expiry_is_original_phase_bound_and_independent_of_later_messages(self):
        s=source('drivingQueueAgreementServer')
        timer=s.split('private _scheduleExpiry={',1)[1].split('if (_mode == "BEGIN")',1)[0]
        for guard in ('localNamespace getVariable','(_live get "phase") != _phase','!= _until','_registry deleteAt _token'):
            self.assertIn(guard,timer)
        self.assertLess(timer.index('isNil {'),timer.index('_live set ["phase","RELEASED"]'))
        self.assertIn('(_until-serverTime) max 0] call CBA_fnc_waitAndExecute',timer)
        self.assertEqual(s.count('call _scheduleExpiry'),2)
        self.assertNotIn('call CBE_fnc_DrivingQueueProposalCurrent',timer)
        for forbidden in ('doMove','doStop','forceSpeed','nearEntities','setDriveOnPath'):
            self.assertNotIn(forbidden,timer)
    def test_owner_expiry_checks_whole_canonical_receipt_and_never_downgrades_agreed(self):
        s=source('drivingQueueAgreementOwner')
        timer=s.split('private _scheduleExpiry={',1)[1].split('// Terminal token cleanup',1)[0]
        self.assertIn('([_old] call _receiptKey) isEqualTo _key',timer)
        self.assertIn('forEach _vehicles',timer)
        self.assertIn('if (_retired) then',timer)
        duplicate=s.split('if (_duplicate) exitWith {',1)[1].split('if (_mode == "VERIFY") exitWith {',1)[0]
        self.assertIn('if (_mode == "VERIFY") then',duplicate)
        self.assertIn('"ACK",[_token,true]',duplicate)
        self.assertLess(s.index('private _accepted='),s.index('if (_duplicate) exitWith {'))
        self.assertLess(s.index('count _request != 4'),s.index('if (_duplicate) exitWith {'))
        self.assertLess(duplicate.index('if (!_accepted) exitWith'),duplicate.index('"ACK",[_token,true]'))
        refusal=duplicate.split('if (!_accepted) exitWith',1)[1].split('if (_mode == "VERIFY") then',1)[0]
        self.assertIn('(_old getOrDefault ["token",""]) == _token',refusal)
        self.assertIn('"RELEASE",[_token]',refusal)
        self.assertIn('"CBE_DrivingQueue_Consent",nil',refusal)
        self.assertNotIn('"ACK",[_token,true]',refusal)
        self.assertNotIn('call _scheduleExpiry',duplicate)
        self.assertIn('if (!_pendingDuplicate) then {[_pendingKey] call _scheduleExpiry}',s)
        self.assertIn('"deadline","expires","phase"',s)
    def test_late_owner_refusal_releases_agreement_before_duplicate_reply(self):
        s=source('drivingQueueAgreementServer')
        begin=s.index('if ((_record get "phase") == "AGREED" && {!(_payload select 1)}) exitWith')
        end=s.index('if ((_record get "phase") != "PENDING") exitWith',begin)
        refusal=s[begin:end]
        self.assertIn('_record set ["phase","RELEASED"]',refusal)
        self.assertLess(refusal.index('[_record] call _send'),refusal.index('_registry deleteAt _token'))
        self.assertLess(s.index('_sender in (_record get "owners")'),begin)
        self.assertNotIn('call _scheduleExpiry',refusal)
        self.assertNotIn('set ["expires"',refusal)
        for command in ('doMove','doStop','setDriveOnPath','forceSpeed'):
            self.assertNotIn(command,refusal)

    def test_closed_tokens_block_deferred_owner_readmission_without_extending_expiry(self):
        owner=source('drivingQueueAgreementOwner')
        closed=source('drivingQueueTokenClosed')
        self.assertLess(owner.index('private _tokenClosed='),owner.index('private _accepted='))
        self.assertIn('private _accepted=!_tokenClosed',owner)
        terminal=owner.split('// Terminal token cleanup',1)[1].split('private _tokenClosed=',1)[0]
        self.assertLess(terminal.index('call CBE_fnc_DrivingQueueTokenClosed'),terminal.index('if (_owned isEqualTo [])'))
        verify=owner.split('if (_mode == "VERIFY") exitWith {',1)[1].split('["ACK",[_token,_accepted]]',1)[0]
        self.assertIn('} else {',verify)
        self.assertIn('call CBE_fnc_DrivingQueueTokenClosed',verify)
        self.assertIn('(_old getOrDefault ["token",""]) == _token',verify)
        timer=owner.split('private _scheduleExpiry={',1)[1].split('// Terminal token cleanup',1)[0]
        self.assertIn('[_key select 0,_key select 7] call CBE_fnc_DrivingQueueTokenClosed',timer)
        self.assertIn('count _closed > 64',closed)
        self.assertIn('count _closed < 64',closed)
        self.assertIn('(_closed get _token) min _closeUntil',closed)
        self.assertIn('_live >= 64',closed)
        self.assertIn('if (_unknown) exitWith {true}',closed)
        self.assertIn('remoteExecutedOwner != 2',closed)
        for forbidden in ('remoteExecCall','waitAndExecute','doMove','doStop','setDriveOnPath','forceSpeed','nearEntities'):
            self.assertNotIn(forbidden,closed.split('params [[',1)[1])

    def test_local_cancellation_closes_exact_consent_before_server_roundtrip(self):
        for name in ('drivingQueueAgreementRelease','drivingQueueAgreementRequest'):
            s=source(name)
            self.assertLess(s.index('call CBE_fnc_DrivingQueueTokenClosed'),s.index('["RELEASE",['))
            self.assertLess(s.index('call CBE_fnc_DrivingQueueTokenClosed'),s.index('setVariable ["CBE_DrivingQueue_Consent",nil]'))

    def test_server_bounds_timer_churn_across_fresh_serial_release_cycles(self):
        s=source('drivingQueueAgreementServer')
        for guard in ('"CBE_DrivingQueue_Admissions"','serverTime < (_admissions getOrDefault',
                      'count _admissions >= 64','_admissions set [_admissionKey,serverTime+30]'):
            self.assertIn(guard,s)
        self.assertLess(s.index('count _admissions >= 64'),s.index('_registry set [_token,_record]'))
        self.assertLess(s.index('_admissions set [_admissionKey'),s.index('[_record] call _scheduleExpiry'))
        self.assertIn('count _registry >= 32',s)

    def test_driving_finish_retires_only_exact_epoch_generation_queue_consent(self):
        finish=source('drivingOperationFinish')
        release=source('drivingQueueAgreementRelease')
        self.assertLess(finish.index('call CBE_fnc_DrivingQueueAgreementRelease'),finish.index('if (isNull _group || {!local _group}'))
        for guard in ('local _vehicle','remoteExecutedOwner != 2','count _context > 4',
                      '(_row select 1) != clientOwner','count _actorReceipt != 11',
                      '(_actorReceipt select 2) isNotEqualTo _expectedGroup',
                      '(_actorReceipt select 4) isNotEqualTo _expectedEpoch',
                      '(_actorReceipt select 5) isNotEqualTo _expectedGeneration',
                      'forEach [2,3]','isEqualTo _consent','if (!_retired) exitWith {false}',
                      '["RELEASE",[_token]] remoteExecCall'):
            self.assertIn(guard,release)
        executable=release.split('params [[',1)[1]
        for forbidden in ('doMove','doStop','forceSpeed','setDriveOnPath','nearEntities','waitAndExecute'):
            self.assertNotIn(forbidden,executable)
        self.assertLess(release.index('if (!_matches) exitWith'),release.index('setVariable ["CBE_DrivingQueue_Consent",nil]'))
        self.assertIn('class DrivingQueueAgreementRelease', (ROOT/'addons/main/CfgFunctions.hpp').read_text())

if __name__=='__main__':unittest.main()
