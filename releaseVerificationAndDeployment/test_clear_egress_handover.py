"""Egress must yield to individual destination replacement before arrival or retry."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ClearEgressHandoverTests(unittest.TestCase):
    def test_individual_order_filters_arrivals_and_retry_without_losing_failure(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        egress = source.split('if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {', 1)[1]
        selection = egress.split('private _outsideExit={', 1)[0]
        self.assertIn('currentCommand _unit == "MOVE" && {!([_unit] call _ownsCurrentMove)}', selection)
        self.assertIn('_diverted pushBackUnique _unit', selection)
        self.assertIn('deleteAt (netId _unit)', selection)
        self.assertIn('_x set [2,false]', selection)
        self.assertIn('!(_unit in _diverted)', selection)
        self.assertIn('if (count _assignments < count (_job get "egressAssignments")) then {_job set ["egressFailed",true]}', selection)
        self.assertIn('_assignments findIf {[_x] call _outsideExit}', egress)
        self.assertIn('forEach _assignments', egress)
        finish = source.split('private _handbacks=[];', 1)[1].split('private _delay', 1)[0]
        self.assertIn('currentCommand _x != "MOVE" || {[_x] call _ownsCurrentMove}', finish)

if __name__ == '__main__':
    unittest.main()
