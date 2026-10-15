"""Smoke classification must reject explosive/mixed trees; live shell delivery is separate."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SmokePayloadTests(unittest.TestCase):
    def test_payload_validation_precedes_smoke_leaf_acceptance(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        classify=s.split('private _classifySmoke =',1)[1].split('private _profile',1)[0]
        for guard in ('_smokeChecks > 64','_depth >= 4','!finite _indirect','_indirect != 0','count _payloads <= 16','_payloads findIf {!(_x isEqualType "")','_payloads findIf {!([_x,_depth+1]'):
            self.assertIn(guard,classify)
            self.assertLess(classify.index(guard),classify.index('_simulation in ["shotsmoke","shotsmokex"]'))
        self.assertNotIn('aiAmmoUsageFlags',classify)
        self.assertNotIn('select {_x isEqualType ""}',classify)
        self.assertIn('_smokeChecks=0;',s)
if __name__=='__main__': unittest.main()
