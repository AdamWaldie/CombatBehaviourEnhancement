"""Tracked reverse cleanup must never cancel a replaced published episode."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ReverseReleaseCommit(unittest.TestCase):
    def test_release_checks_current_published_records_before_native_stops(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicleReverseStep.sqf').read_text(encoding='utf-8')
        body=text.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        for guard in ('isNil {','isEqualTo _entryRecord','isEqualTo _commandReceipt',
                      'call _commandsUnchanged','CBE_ExternalDrivingOwner'):
            self.assertLess(body.index(guard),body.index('sendSimpleCommand'))
        self.assertIn('private _record=+(_group getVariable',text)
        self.assertIn('private _entryRecord=+_record',text)
        self.assertIn('private _commandReceipt=+(_group getVariable',text)
        self.assertNotIn('lineIntersects',body)
        self.assertNotIn('doMove',body)
    def test_retirement_and_progress_compare_original_not_locally_edited_record(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicleReverseStep.sqf').read_text(encoding='utf-8')
        release=text.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        self.assertNotIn('isEqualTo _record)',release)
        self.assertIn('isEqualTo _entryRecord',release)
        tail=text.split('if (_record isNotEqualTo _beforeRecord) then {',1)[1]
        for guard in ('isNil {','local _group','ownerEpoch','isEqualTo _entryRecord','isEqualTo _commandReceipt'):
            self.assertLess(tail.index(guard),tail.index('setVariable ["CBE_VehicleReverse",_record,true]'))
if __name__=='__main__': unittest.main()
