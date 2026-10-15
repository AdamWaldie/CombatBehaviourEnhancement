"""Combined-arms contact transport admission; static/analytic, not physical acceptance."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CombinedContactPayloadTests(unittest.TestCase):
    def test_request_server_owner_share_finite_three_coordinate_boundary(self):
        files=['cortexCombinedArmsRequest','cortexCombinedArmsServer','cortexCombinedArmsLocal']
        for name in files:
            s=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            self.assertIn('count _position != 3',s)
            self.assertIn('!finite _x',s)
            self.assertIn('abs _x > 1e6',s)
            boundary=s.index('count _position != 3')
            if name.endswith('Request'):
                self.assertLess(boundary,s.index('_state set ["combinedArmsDue"'))
            elif name.endswith('Server'):
                self.assertLess(boundary,s.index('_requester setVariable ["WAIT_Cortex_CombinedDue"'))
            else:
                self.assertLess(boundary,s.index('private _asset='))
    def test_invalid_positions_cannot_be_valid_contact_vectors(self):
        def admitted(p):
            return isinstance(p,list) and len(p)==3 and all(type(v) in (int,float) and math.isfinite(v) and abs(v)<=1e6 for v in p)
        for p in ([1,2],[1,2,3,4],[1,2,float('nan')],[float('inf'),2,3],[1,2,'3'],[1,2,1e6+1]):
            self.assertFalse(admitted(p),repr(p))
        self.assertTrue(admitted([1250,3500,0]))
        self.assertTrue(admitted([-1e6,1e6,-10]))
if __name__=='__main__':unittest.main()
