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
        commands=text.split('private _commandsUnchanged={',1)[1].split('private _release=',1)[0]
        self.assertIn('vehicleMoveInfo _ownedVehicle',commands)
        self.assertIn('["FORWARD","FAST","SLOW","DIRECTBYCOMANDER"]',commands)
        self.assertIn('+(vehicleMoveInfo _vehicle)] isEqualTo _nativeSnapshot',text)
    def test_retirement_and_progress_compare_original_not_locally_edited_record(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicleReverseStep.sqf').read_text(encoding='utf-8')
        release=text.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        self.assertNotIn('isEqualTo _record)',release)
        self.assertIn('isEqualTo _entryRecord',release)
        tail=text.split('if (_record isNotEqualTo _beforeRecord) then {',1)[1]
        for guard in ('isNil {','local _group','ownerEpoch','isEqualTo _entryRecord','isEqualTo _commandReceipt'):
            self.assertLess(tail.index(guard),tail.index('setVariable ["CBE_VehicleReverse",_record,true]'))
    def test_start_and_steering_commit_after_fresh_context_check(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicleReverseStep.sqf').read_text(encoding='utf-8')
        proof=text.split('private _commitReady={',1)[1].split('if (toUpperANSI _mode == "START")',1)[0]
        for guard in ('ownerEpoch','CortexActorMoveReserved','CortexZeusHeld','CortexIsPaused',
                      'isEqualTo _nativeSnapshot','isEqualTo _entryRecord','isEqualTo _commandReceipt',
                      'time-(_poseSnapshot select 2) <= 1','vectorDistance (_poseSnapshot select 0) <= 1','cos 5'):
            self.assertIn(guard,proof)
        self.assertNotIn('lineIntersects',proof)
        start=text.split('private _started=false;',1)[1].split('if (count _record != 9',1)[0]
        for guard in ('isNil {','call _commitReady','time < _startDeadline'):
            self.assertLess(start.index(guard),start.index('sendSimpleCommand "BACK"'))
        self.assertLess(text.index('private _startDeadline='),text.index('call CBE_fnc_CortexSelectAvenue'))
        steering=text.split('private _steeringLost=false;',1)[1].split('if (_record isNotEqualTo',1)[0]
        self.assertLess(steering.index('call _commitReady'),steering.index('sendSimpleCommand _turn'))
        self.assertIn('time < (_record select 5)',steering)
        self.assertIn('if (_steeringLost) exitWith',steering)
        self.assertLess(steering.index('setVariable ["CBE_VehicleReverse_Command"'),steering.index('_steered=true'))
        self.assertLess(steering.index('setVariable ["CBE_VehicleReverse",_record,true]'),steering.index('_steered=true'))
        self.assertIn('_beforeRecord=+_record',steering)
if __name__=='__main__': unittest.main()
