"""Convoy hold command/receipt authority contracts; not physical acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyHoldAuthority(unittest.TestCase):
    def test_startup_receipts_follow_actual_seat_checks_and_stop(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        seat=s.split('[_taskDriver,_taskOperator] findIf {',1)[1].split('} < 0',1)[0]
        for guard in ('!simulationEnabled _x','isObjectHidden _x','ace_medical_ai_healQueue'):
            self.assertIn(guard,seat)
        self.assertNotIn('setVariable',seat)
        startup=s.split('private _initialPathOwners=',1)[1].split('_state set ["pathOwners"',1)[0]
        fixed=startup.split('private _initialVehicle=_x;',1)[1].split('} else {',1)[0]
        self.assertLess(fixed.index('isNil {if ([_initialVehicle] call _mayIssueDriving)'),fixed.index('doStop driver _initialVehicle'))
        self.assertLess(fixed.index('doStop driver _initialVehicle'),fixed.index('_initialPathOwners set'))
        native=startup.split('private _initialOperator=',1)[1]
        self.assertLess(native.index('isNil {if ([_initialVehicle,_initialOperator] call _mayIssueDriving)'),native.index('doStop _initialOperator'))
        self.assertLess(native.index('doStop _initialOperator'),native.index('_initialProgress set [7,true]'))
    def test_waiting_for_trail_commits_only_owned_holds(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        branch=s.split('// A steering-capable follower waits for a forward trail;',1)[1]
        self.assertEqual(branch.count('isNil {if ([_vehicle,_movementOperator] call _mayIssueDriving)'),2)
        native=branch.split('doStop _movementOperator;',1)[1]
        self.assertLess(native.index('_progress set [7,true]'),native.index('}};'))
        fixed=branch.split('doStop driver _vehicle;',1)[1]
        self.assertLess(fixed.index('_pathOwners set [_key,true]'),fixed.index('}};'))
        self.assertNotIn('[] call _mayIssueDriving',branch)
if __name__=='__main__': unittest.main()
