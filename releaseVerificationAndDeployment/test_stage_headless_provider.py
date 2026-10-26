import hashlib
from pathlib import Path
import tempfile
import unittest
from stage_headless_provider import REQUIRED, stage_provider

class HeadlessProviderStagingTests(unittest.TestCase):
    def test_missing_provider_is_rejected_before_mutating_mission(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            mission=root/'mission'; mission.mkdir()
            with self.assertRaises(ValueError): stage_provider(root/'missing',mission)
            self.assertEqual(list(mission.iterdir()),[])

    def test_real_bytes_and_function_bindings_are_preserved_and_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            source=root/'repo/MissionScripts/Headless'; source.mkdir(parents=True)
            mission=root/'mission'; mission.mkdir()
            for name in REQUIRED:
                (source/name).write_bytes(('/* '+name+' */\ntrue;').encode())
            evidence=stage_provider(root/'repo',mission)
            destination=mission/'compatibilityHeadlessProvider'
            for name in REQUIRED:
                self.assertEqual((destination/name).read_bytes(),(source/name).read_bytes())
                self.assertEqual(evidence['files'][name],hashlib.sha256((source/name).read_bytes()).hexdigest())
            loader=(destination/'init.sqf').read_text()
            self.assertIn('Waldo_fnc_HeadlessMigrateGroup=compile',loader)
            self.assertIn('[] call Waldo_fnc_HeadlessDetectLocal',loader)
            self.assertIn('private _result=_this call CBE_QA_NativeRegisterOriginal;',loader)
            self.assertIn('_observed < 30',loader)
            self.assertEqual(evidence['scope'],'EXPLICIT_NATIVE_TRANSFERS_ONLY')
            repo=Path(__file__).resolve().parents[1]
            audit=(repo/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text()
            wrapper=audit.split('CBE_fnc_HeadlessMigrateGroup={',1)[1]
            self.assertLess(wrapper.index('CBE_Headless_ExcludeGroup'),
                            wrapper.index('call Waldo_fnc_HeadlessMigrateGroup'))
            heli=(repo/'addons/aircraft/functions/improvedHelicopterLandingInit.sqf').read_text()
            ground=(repo/'addons/aircraft/functions/cortexAirborneGroundHandover.sqf').read_text()
            self.assertIn('"Waldo_Headless_ExcludeGroup", true, true',heli)
            self.assertNotIn('"CBE_Headless_ExcludeGroup"',heli)
            self.assertIn('"Waldo_Headless_ExcludeGroup"',ground)
            with self.assertRaises(ValueError): stage_provider(root/'repo',mission)
