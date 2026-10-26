"""Convoy explicit fire ownership/safety contracts, not live firing acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyFireLaneTests(unittest.TestCase):
    def test_mounted_fire_uses_shared_veto_and_retires_only_matching_target(self):
        source=(ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text(encoding='utf-8')
        fire=source.split('if (_fireReady &&',1)[1].split('} forEach fullCrew',1)[0]
        self.assertLess(fire.index('call CBE_fnc_CortexLineOfFireClear'),fire.index('_unit doFire _enemy'))
        self.assertIn('weaponState [_vehicle,_turretPath]',fire)
        self.assertIn('count _loaded >= 7',fire)
        self.assertIn('(_loaded select 4) > 0',fire)
        self.assertIn('(_loaded select 6) == 0',fire)
        self.assertIn('[_unit,aimPos _enemy,_fireMagazine]',fire)
        self.assertLess(fire.index('weaponState [_vehicle,_turretPath]'),fire.index('call CBE_fnc_CortexLineOfFireClear'))
        # Counterexample: a friendly outside the narrow cone but within an HE
        # aimpoint blast radius passed the old cone-only convoy invocation.
        import math
        target=(100,0,0)
        friendly=(100,15,0)
        along=friendly[0]
        cone_unsafe=math.hypot(friendly[1],friendly[2]) < 2+along*.087
        def veto(indirect_range,damage):
            radius=max(12,4*indirect_range) if damage>0 else 0
            return cone_unsafe or (radius>0 and math.dist(friendly,target)<=radius)
        self.assertFalse(veto(0,0))  # ordinary bullet: no invented blast radius
        self.assertTrue(veto(5,20)) # 20m config exclusion catches the same flank position
        refusal=fire.split('} else {',1)[1]
        self.assertIn('assignedTarget _unit == _previous',refusal)
        self.assertIn('_unit doTarget objNull',refusal)
        self.assertIn('CBE_Convoy_Target',refusal)
        for forbidden in ('doMove','doFollow','setCombatMode','disableAI','forceSpeed'):
            self.assertNotIn(forbidden,fire)
    def test_operator_and_platform_availability_precede_fire(self):
        source=(ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text(encoding='utf-8')
        ready=source.split('private _fireReady=',1)[1].split('if (local _unit',1)[0]
        for marker in ('!_passenger','CortexCombatEffective','simulationEnabled _unit','isObjectHidden _unit',
                       'simulationEnabled _vehicle','isObjectHidden _vehicle','CortexExternalTakeover'):
            self.assertIn(marker,ready)
        self.assertIn('!_fireReady ||',source)
        self.assertIn('_fireEnabled && {_fireTaskAvailable} && {!_assignmentReplaced}',source)
        self.assertLess(source.index('call CBE_fnc_CortexActorFireTaskAvailable'),source.index('call CBE_fnc_ConvoyThreat'))
        self.assertEqual(source.count('if (_fireTaskAvailable && {!isNull _previous} && {assignedTarget _unit == _previous})'),2)
        protected_cleanup=source.split('if (local _unit && {!isPlayer _unit} && {!_fireReady',1)[1].split('if (_fireReady &&',1)[0]
        self.assertIn('CBE_Convoy_Target", nil, true',protected_cleanup)
        self.assertNotIn('doMove',protected_cleanup)

if __name__=='__main__': unittest.main()
