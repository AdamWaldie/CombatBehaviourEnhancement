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
        duplicate=s.split('private _duplicate=',1)[1].split('private _accepted=',1)[0]
        self.assertIn('if (_mode == "VERIFY") then',duplicate)
        self.assertIn('"ACK",[_token,true]',duplicate)
        self.assertIn('private _stillCurrent=[_vehicles,_roles,_dependencies,_context,true]',duplicate)
        self.assertLess(duplicate.index('if (!_stillCurrent) exitWith'),duplicate.index('"ACK",[_token,true]'))
        refusal=duplicate.split('if (!_stillCurrent) exitWith',1)[1].split('if (_mode == "VERIFY") then',1)[0]
        self.assertIn('(_old getOrDefault ["token",""]) == _token',refusal)
        self.assertIn('"RELEASE",[_token]',refusal)
        self.assertIn('"CBE_DrivingQueue_Consent",nil',refusal)
        self.assertNotIn('"ACK",[_token,true]',refusal)
        self.assertNotIn('call _scheduleExpiry',duplicate)
        self.assertIn('if (!_pendingDuplicate) then {[_pendingKey] call _scheduleExpiry}',s)
        self.assertIn('"deadline","expires","phase"',s)
    def test_server_bounds_timer_churn_across_fresh_serial_release_cycles(self):
        s=source('drivingQueueAgreementServer')
        for guard in ('"CBE_DrivingQueue_Admissions"','serverTime < (_admissions getOrDefault',
                      'count _admissions >= 64','_admissions set [_admissionKey,serverTime+30]'):
            self.assertIn(guard,s)
        self.assertLess(s.index('count _admissions >= 64'),s.index('_registry set [_token,_record]'))
        self.assertLess(s.index('_admissions set [_admissionKey'),s.index('[_record] call _scheduleExpiry'))
        self.assertIn('count _registry >= 32',s)
if __name__=='__main__':unittest.main()
