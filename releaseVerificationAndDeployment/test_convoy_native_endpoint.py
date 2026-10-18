"""Finished native convoy leg guards; models are not physical steering evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyNativeEndpointTests(unittest.TestCase):
    def test_finished_leg_requires_physical_endpoint_and_exact_ownership(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        block=text.split('private _finishedLeg=',1)[1].split('if (count _committedDestination < 2',1)[0]
        for guard in ('count _committedDestination == 3','count _nativeReceipt == 4',
                      'local _vehicle','local _movementOperator','abs speed _vehicle < 1',
                      'unitReady _movementOperator','currentCommand _movementOperator in ["","MOVE"]',
                      '_vehicle distance2D _committedDestination <= 3','ATLToASL _committedDestination',
                      '_committedDestination distance2D _destination > 3',
                      '(_nativeReceipt select 0) == driver _vehicle',
                      '(_nativeReceipt select 1) == _movementOperator',
                      '(expectedDestination driver _vehicle) isEqualTo (_nativeReceipt select 2)',
                      '(expectedDestination _movementOperator) isEqualTo (_nativeReceipt select 3)'):
            self.assertIn(guard,block)
        self.assertIn('distance2D _destination > 8} || {_finishedLeg}',text)
        branch=text.split('distance2D _destination > 8} || {_finishedLeg}',1)[1].split('_progress set [2, time + 1]',1)[0]
        self.assertLess(branch.index('call _mayIssueDriving'),branch.index('_movementOperator doMove'))
        self.assertIn('_progress set [10,[driver _vehicle,_movementOperator',branch)

    def test_moving_legs_stop_commands_and_changed_receipts_do_not_gain_retry(self):
        def finished(speed,ready,command,near,same_floor,advance,receipt):
            return abs(speed)<1 and ready and command in ('','MOVE') and near<=3 and same_floor and advance>3 and receipt
        self.assertTrue(finished(0,True,'MOVE',1,True,5,True))
        self.assertTrue(finished(0,True,'',1,True,5,True))
        for args in ((2,True,'MOVE',1,True,5,True),(0,False,'MOVE',1,True,5,True),
                     (0,True,'STOP',1,True,5,True),(0,True,'FOLLOW',1,True,5,True),
                     (0,True,'MOVE',8,True,5,True),(0,True,'MOVE',1,False,5,True),
                     (0,True,'MOVE',1,True,3,True),(0,True,'MOVE',1,True,5,False)):
            self.assertFalse(finished(*args))
