"""Clear-module selection/dispatch contracts, not proof of physical clearance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearModuleTests(unittest.TestCase):
    def test_module_uses_explicit_selectors_and_real_authenticated_dispatch(self):
        s=(ROOT/'addons/infantry/functions/zenClearModule.sqf').read_text(encoding='utf-8')
        for field in ('["Squad",','["Building",','["group",_group]','["building",_building]','["order","CLEAR"]','WAIT_fnc_CortexOrderDispatch'):
            self.assertIn(field,s)
        for forbidden in ('setPos','CBA_fnc_addSetting','CBA_settings_fnc_set','CortexClearBuilding;','remoteExecCall'):
            self.assertNotIn(forbidden,s)
        self.assertIn('min 128',s)
        self.assertIn('_buildings=[_target]+(_buildings-[_target])',s)
        self.assertIn('_groups=[_selected]+(_groups-[_selected])',s)
        self.assertLess(s.index('_buildings isEqualTo []'),s.index('call zen_dialog_fnc_create'))
if __name__=='__main__': unittest.main()
