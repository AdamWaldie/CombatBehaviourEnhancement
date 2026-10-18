"""Regression guards for total-motion admission, not native-driving acceptance."""
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingStationarityTests(unittest.TestCase):
    def test_recovery_and_waits_reject_non_forward_motion(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        gate=text.split('private _stationary={',1)[1].split('};',1)[0]
        self.assertIn('vectorMagnitude velocity _candidate',gate)
        self.assertIn('finite _linearSpeed && {_linearSpeed < (1/3.6)}',gate)
        self.assertNotIn('abs speed _vehicle',text)
        self.assertNotIn('abs speed _jamPeer',text)
        self.assertIn('([_jamPeer] call _stationary)',text)
        self.assertGreaterEqual(text.count('[_vehicle] call _stationary'),5)
        self.assertIn('(_jam get "attempts") < 3',text)
        self.assertIn('serverTime < (_jam get "deadline")',text)
    def test_total_motion_threshold_examples(self):
        # Independent arithmetic examples: these do not execute SQF or prove settled vehicles.
        cases=[((0,0,0),True),((0.1,0,0),True),((1,0,0),False),
               ((0,0,1),False),((0,-1,0),False),((float('inf'),0,0),False),
               ((float('nan'),0,0),False),((1/3.6,0,0),False)]
        for velocity,expected in cases:
            magnitude=math.sqrt(sum(axis*axis for axis in velocity))
            self.assertEqual(math.isfinite(magnitude) and magnitude < 1/3.6,expected)

    def test_reverse_target_retains_observed_deck_height_and_rejects_open_water(self):
        rear=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text(encoding='utf-8')
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('modelToWorldWorld [0,-_distance,(_low select 2)+1.2]',rear)
        self.assertIn('private _destination=ASLToAGL (_targetHit select 0);',rear)
        self.assertIn('surfaceIsWater _destination && {(_destination select 2) < 0',rear)
        self.assertIn('isNull (_targetHit select 2) && {isNull (_targetHit select 3)}',rear)
        self.assertIn('time,_rays,_destination]',rear)
        self.assertIn('_rear=+(_clearance param [4,[]]);',start)
        self.assertNotIn('surfaceIsWater _rear',start)
        self.assertNotIn('_vehicle getPos [8,(getDir _vehicle)+180]',start)
        self.assertIn('_movementOperator doMove _rear',start)

    def test_rear_recovery_tracks_component_damage_without_suppression(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        reader=(ROOT/'addons/vehicles/functions/drivingDamageReceipt.sqf').read_text(encoding='utf-8')
        for marker in ('getAllHitPointsDamage','_count > 128','finite _x','_table apply {+_x}'):
            self.assertIn(marker,reader)
        self.assertIn('_work set ["rearHitpoints",_rearHitpointReceipt apply {+_x}]',text)
        self.assertIn('(_rearHitpoints select [0,2]) isEqualTo (_liveHitpoints select [0,2])',text)
        self.assertIn('|| {_componentDamage}',text)
        self.assertLess(text.index('([_vehicle] call CBE_fnc_DrivingDamageReceipt) isNotEqualTo _rearHitpointReceipt'),text.index('_movementOperator doMove _rear'))
        for forbidden in ('setDamage','setHitPointDamage','setHitIndex','allowDamage','HandleDamage'):
            self.assertNotIn(forbidden,text)

    def test_convoy_arrival_retains_continuous_full_motion_settlement(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        window=text.split('private _settled =',1)[1].split('// Record each predecessor',1)[0]
        for marker in ('vectorMagnitude velocity _x','vectorMagnitude angularVelocity _x',
                       '!finite _linearMotion','!finite _angularMotion',
                       '_linearMotion >= (1/3.6)','_angularMotion >= 0.01',
                       'if (!_settled) then {_state set ["arrivalAt", time + 5]}',
                       '_settled && {time >=','"ARRIVED"'):
            self.assertIn(marker,window)
        self.assertNotIn('abs speed _x',window)
        self.assertLess(window.index('vectorMagnitude velocity'),window.index('"ARRIVED"'))
