"""Finite rear-leg safety and scheduler contracts, not native braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(n):return (ROOT/'addons/vehicles/functions'/f'{n}.sqf').read_text(encoding='utf-8')
class DrivingRearMonitorTests(unittest.TestCase):
    def test_rear_observation_applies_before_speed_write_without_extending_deadline(self):
        s=src('drivingAssistStart')
        sample=s.split('if (_reverseLeg) then {',1)[1].split('private _trafficLimited=',1)[0]
        self.assertIn('[_vehicle,8] call WAIT_fnc_DrivingRearClear',sample)
        self.assertIn('_traffic=[0,_vehicle,-1,time,0]',sample)
        self.assertNotIn('_recoveryUntil=',sample)
        self.assertLess(s.index('private _rearObservation='),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('if (_reverseExpired && {!_retryAllowed}) then {_traffic=[0,_vehicle,-1,time,0]}',s)
    def test_direction_and_issued_receipt_survive_stop_and_expire(self):
        s=src('drivingAssistStart')
        self.assertIn('_state param [10,',s)
        self.assertIn('_recoveryResult="CAUTIOUS_REVERSE";_reverseIssued=true',s)
        self.assertIn('_recoveryResult="REAR_BLOCKED";_reverseIssued=false',s)
        self.assertIn('_recoveryResult="FINAL_ROUTE_RETRY";_reverseIssued=false',s)
        self.assertIn('if (_reverseLeg) then {-1}',s)
        self.assertIn('_routeIdentity,_reverseIssued',s)
        observer=(ROOT/'addons/infantry/functions/cortexInfantrySpeed.sqf').read_text(encoding='utf-8')
        self.assertIn('["_travelIntent",0,[0]]',observer)
        self.assertIn('if (_travelIntent == 0)',observer)
    def test_existing_scheduler_samples_active_rear_stage_faster(self):
        self.assertIn('time+([4,1] select (_trafficLimited || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))',src('drivingAssistStart'))
        self.assertIn('_rearLeg=_rearLeg || {(_state param [6,0]) == 2}',src('drivingOperationStep'))
        self.assertIn('time+([4,1] select (_traffic || {_obstacle} || {_rearLeg} || {_corridor != ""} || {_bypass != ""}))',src('drivingOperationStep'))
if __name__=='__main__':unittest.main()
