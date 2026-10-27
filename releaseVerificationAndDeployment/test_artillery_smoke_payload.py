"""Smoke classification must reject explosive/mixed trees; live shell delivery is separate."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SmokePayloadTests(unittest.TestCase):
    def test_payload_validation_precedes_smoke_leaf_acceptance(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        classify=s.split('private _classifyPayload =',1)[1].split('private _profile',1)[0]
        for guard in ('_payloadChecks > 64','_depth >= 4','!finite _indirect','_indirect != 0','count _payloads <= 16','_payloads findIf {!(_x isEqualType "")','_payloads findIf {!([_x,_depth+1,_kind]'):
            self.assertIn(guard,classify)
            self.assertLess(classify.index(guard),classify.index('_simulation in ["shotsmoke","shotsmokex"]'))
        self.assertNotIn('aiAmmoUsageFlags',classify)
        self.assertNotIn('select {_x isEqualType ""}',classify)
        self.assertIn('_payloadChecks=0;',s)
        for proof in ('_kind == "ILLUM"','_simulation == "shotilluminating"',
                      '!finite _explosive','_explosive != 0'):
            self.assertIn(proof,classify)
        self.assertIn('if (!(_mode in ["HE","SMOKE","ILLUM"])) exitWith {""}',s)
        self.assertIn('case "ILLUM": {_isIllum}',s)
        self.assertIn('default {!_isSmoke && {!_special}',s)
        self.assertIn('count _profile != 4',s)
        self.assertIn('_exactMagazine == "" || {_magazine == _exactMagazine}',s)

    def test_smoke_gate_reaches_admission_continuation_and_owner_release(self):
        base=ROOT/'addons/support/functions'
        ammo=(base/'cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        self.assertIn('_target isEqualTo [] || {_target inRangeOfArtillery [[_battery],_x]}',ammo)
        self.assertLess(ammo.index('!finite _x'),ammo.index('magazinesAllTurrets'))
        ranking=ammo.split('_profile params',1)[1]
        self.assertLess(ranking.index('inRangeOfArtillery'),ranking.index('_best = _x'))
        fire=(base/'cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        self.assertIn('_mode != "SMOKE" || {[group gunner _x,"CBE_AIPass_ArtillerySmoke_Enable"',fire)
        self.assertIn('[_x, _mode,_target] call CBE_fnc_CortexArtilleryAmmo',fire)
        self.assertIn('[_battery, _mode,_target] call CBE_fnc_CortexArtilleryAmmo',fire)
        explicit=fire.split('if (isNull _battery || {!alive gunner _battery}',1)[1]
        self.assertLess(explicit.index('CBE_AIPass_ArtillerySmoke_Enable'),explicit.index('CBE_AIPass_FireSerial'))
        mission=(base/'cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _blocked = _counterExpired || {_fireExpired} || {_smokeExpired} || {_smokeBlocked}',mission)
        self.assertIn('CBE_AIPass_ArtillerySmoke_Enable',mission)
        self.assertIn('{_illuminationBlocked}',mission)
        self.assertIn('getEnvSoundController "night" <= 0.7',mission)
        self.assertIn('_mode == "ILLUM" && {!_danger',fire)
        self.assertLess(fire.index('_mode == "ILLUM" && {!_danger'),fire.index('CBE_AIPass_FireSerial'))

        shot=(base/'cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        final=shot.split('// Safety/munition checks',1)[1]
        self.assertIn('_mode != "ILLUM" || {_purpose == "DANGER"',shot)
        self.assertIn('getEnvSoundController "night" > 0.7',shot)
        self.assertIn('[_battery,"ILLUM",_aim,_magazine] call CBE_fnc_CortexArtilleryAmmo',final)
        self.assertLess(final.index('[_battery,"ILLUM",_aim,_magazine]'),final.index('doArtilleryFire'))

        self.assertLess(final.index('CBE_AIPass_ArtillerySmoke_Enable'),final.index('doArtilleryFire'))
    def test_weighted_payloads_are_validated_without_discarding_dangerous_branches(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        for guard in ('count _payloadArray <= 32','count _payloadArray mod 2 == 0','!(_weight isEqualType 0)','!finite _weight','_weight < 0','_positiveWeight','_payloads pushBack _class'):
            self.assertIn(guard,s)
        self.assertNotIn('if (_weight > 0) then {_payloads',s)
        self.assertLess(s.index('_validPayload=_validPayload && {_positiveWeight}'),s.index('_payloads findIf {!([_x,_depth+1,_kind]'))
if __name__=='__main__': unittest.main()
