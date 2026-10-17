"""CBE first-release namespace, source resolution and package branding contracts."""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class CbeNamingContracts(unittest.TestCase):
    def test_only_cbe_tag_and_all_registered_sources_resolve(self):
        source=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        self.assertRegex(source,r'class\s+CBE\s*\{\s*tag\s*=\s*"CBE";')
        self.assertNotRegex(source,r'class\s+(?:WAIT|Waldo)\b')
        exports=re.findall(r'class\s+(\w+)\s*\{\s*file\s*=\s*"([^"]+\.sqf)"\s*;\s*\};',source)
        self.assertGreater(len(exports),250)
        self.assertEqual(len(exports),len({name.lower() for name,_ in exports}))
        registered={name.lower() for name,_ in exports}
        for name,path in exports:
            self.assertTrue(path.startswith('\\z\\cbe\\addons\\'),name)
            physical=ROOT/path.replace('\\','/').removeprefix('/z/cbe/')
            self.assertTrue(physical.is_file(),name)
        # Every new in-addon call must resolve to the one declared function tag.
        for path in (ROOT/'addons').rglob('*'):
            if path.suffix.lower() not in {'.sqf','.cpp','.hpp','.fsm'}:continue
            text=path.read_text(encoding='utf-8-sig')
            self.assertNotRegex(text,r'\bWAIT_|waldo_ai_tweaks',str(path))
            code=re.sub(r'/\*.*?\*/|//[^\n]*','',text,flags=re.S)
            for fn in re.findall(r'\bCBE_fnc_(\w+)',code):
                self.assertIn(fn.lower(),registered,f'{path}: {fn}')

    def test_brand_logo_and_virtual_prefix_are_packaged(self):
        mod=(ROOT/'mod.cpp').read_text()
        self.assertIn('name = "Combat Behaviour Enhancement (CBE)";',mod)
        self.assertIn('hidePicture = 0;',mod)
        for key in ['picture','logo','logoOver','logoSmall']:
            target=re.search(rf'(?m)^{key}\s*=\s*"([^"]+)";',mod).group(1)
            self.assertTrue((ROOT/target.replace('\\','/')).is_file(),key)
        project=(ROOT/'.hemtt/project.toml').read_text()
        self.assertIn('prefix = "cbe"',project)
        self.assertIn('"images/branding/*.paa"',project)
        for prefix in (ROOT/'addons').glob('*/$PBOPREFIX$'):
            self.assertTrue(prefix.read_text().strip().startswith('z\\cbe\\addons\\'),str(prefix))
        compatibility=(ROOT/'addons/compatibility/config.cpp').read_text()
        self.assertNotIn('class Waldo_AI_Tweaks_Main',compatibility)

    def test_settings_use_cbe_while_native_wait_commands_are_unchanged(self):
        source=(ROOT/'addons/core/functions/aiTweaksRegisterSettings.sqf').read_text()
        self.assertIn('Combat Behaviour Enhancement (CBE) - ',source)
        self.assertIn('CBE_AITweaks_CBASettingsRegistered',source)
        tuning=(ROOT/'addons/core/functions/cortexTuningSpec.sqf').read_text()
        self.assertIn('"CBE_AIPass_Enable"',tuning)
        native=(ROOT/'addons/vehicles/functions/drivingPassCanConsent.sqf').read_text()
        self.assertIn('["","MOVE","WAIT"]',native)
        self.assertNotIn('["","MOVE","CBE"]',native)

if __name__=='__main__':
    unittest.main()
