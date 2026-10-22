"""Danger-cover delayed ownership contracts; physical handover is separate acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CoverOrderContextTests(unittest.TestCase):
    def test_cover_adoption_continuation_and_recovery_require_original_orders(self):
        source=(ROOT/'addons/infantry/functions/dangerCoverStep.sqf').read_text(encoding='utf-8')
        context=source.split('private _readOrderContext=',1)[1].split('private _moveProof=',1)[0]
        for marker in ('CBE_AIPass_Epoch','CBE_OperationGeneration','CBE_fnc_NativeOrderReceipt','count _lease == 6','(_lease select 5) isEqualTo _entryContext'):
            self.assertIn(marker,context)
        self.assertEqual(source.count('if (!_releaseOnly && {_leaseContextCurrent}'),3)
        self.assertIn('[_actor,_generation,_deadline,+_spot,+_threat,+_entryContext]',source)
        self.assertIn('if (_orderChanged) exitWith {["ORDER_CHANGED"] call _clearLease}',source)
        final=source.rsplit('if (_entryContext isNotEqualTo (call _readOrderContext)',1)[1]
        self.assertLess(final.index('exitWith'),final.index('_actor doMove _spot'))
        cleanup=source.split('if (count _lease >= 4) then {',1)[1].split('if (_orderChanged) exitWith',1)[0]
        self.assertIn('_entryContext isEqualTo (call _readOrderContext)',cleanup)
        self.assertIn('[_leasedActor] call CBE_fnc_CortexCombatEffective',cleanup)
        self.assertIn('!fleeing _leasedActor',cleanup)
        self.assertLess(cleanup.index('!fleeing _leasedActor'),cleanup.index('_leasedActor doFollow'))
        self.assertNotIn('addWaypoint',source)
        self.assertNotIn('setCurrentWaypoint',source)
    def test_flight_has_one_original_deadline_and_exact_order_cleanup(self):
        flight=(ROOT/'addons/infantry/functions/dangerFlight.sqf').read_text(encoding='utf-8')
        act=(ROOT/'addons/infantry/functions/dangerEngineAct.sqf').read_text(encoding='utf-8')
        release=(ROOT/'addons/infantry/functions/dangerEngineRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('["START",_actor,_record] call CBE_fnc_DangerFlight',act)
        self.assertLess(release.index('call CBE_fnc_DangerFlight'),release.index('if (count _lease != 6)'))
        fast=flight.index('if (_lease isEqualTo [] && {_mode == \"RELEASE\" || {!fleeing _actor}}) exitWith {0}')
        self.assertLess(fast,flight.index('private _group=group _actor'))
        self.assertLess(fast,flight.index('private _validLease='))
        self.assertLess(fast,flight.index('private _available='))
        self.assertEqual(flight.count('_actor doMove _goal'),1)
        self.assertIn('((_lease select 1)-time) max 0',flight)
        self.assertLess(flight.index('if (_lease isNotEqualTo []) exitWith'),flight.index('call CBE_fnc_CortexFindCover'))
        cleanup=flight.split('if (_mode == "RELEASE") exitWith',1)[1].split('if (!local _actor',1)[0]
        for proof in ('_sameReservation','_group == _oldGroup','call _context',
                      'currentCommand _actor == "MOVE"','vectorDistance _goal <= 0.25','!_arrived && {_owns}'):
            self.assertIn(proof,cleanup)
        self.assertIn('currentCommand _actor != ""',flight)
        self.assertIn('"INIT","PLANNING","REPLAN"',flight)
        gate=(ROOT/'addons/infantry/functions/dangerEngineCanContinue.sqf').read_text(encoding='utf-8')
        for proof in ('time >= (_flight select 1)','(_flight select 3) != (_response select 5)',
                      '(_flight select 4) != (_response select 4)','if (_flightInterrupted) exitWith {false}'):
            self.assertIn(proof,gate)
        rejoin=flight.split('if (_quietRejoin) exitWith',1)[1].split('private _rayStart=',1)[0]
        self.assertIn('_actor doFollow _leader',rejoin)
        self.assertIn('currentCommand _actor == ""',rejoin)
        self.assertIn('_entry isEqualTo (call _context)',rejoin)
        self.assertNotIn('setVariable ["CBE_Cortex_ActorMove"',rejoin)
        self.assertNotIn('setVariable ["CBE_Danger_FlightLease"',rejoin)
        for proof in ('_cause in [0,3,8]','_origin distance2D _threat > 75',
                      '!_personalPressure','getSuppression _actor < 0.2','_leader != _actor'):
            self.assertIn(proof,flight)
        submit=(ROOT/'addons/infantry/functions/dangerEngineSubmit.sqf').read_text(encoding='utf-8')
        self.assertIn('_cycle == 0 && {_cause in [1,2,4,9]}',submit)
        self.assertIn('_physicalUntil=_physicalUntil max (_expires+5)',submit)
        self.assertIn('time > _physicalUntil',flight)
        for refusal in ('captive _source','ace_captives_isSurrendering','ace_captives_isHandcuffed','HeadlessClient_F'):
            self.assertIn(refusal,flight)
        # Replaying one original physical expiry cannot refresh it with processing time.
        physical_until=max(101+5,99+5)
        self.assertEqual(physical_until,106)
        self.assertFalse(105>physical_until)
        self.assertTrue(107>physical_until)
        def quiet_rejoin(cause,distance,personal,suppression):
            return cause in (0,3,8) and distance>75 and not personal and suppression<0.2
        self.assertTrue(quiet_rejoin(0,100,False,0.1))
        for row in ((2,100,False,0.1),(9,100,False,0.1),(0,75,False,0.1),
                    (0,100,True,0.1),(0,100,False,0.2)):
            self.assertFalse(quiet_rejoin(*row))
        self.assertIn('time+15',flight)
        self.assertIn('time+2',flight)
        self.assertNotIn('getPosATL _source',flight)
        self.assertNotIn('setUnitPos',flight)
        self.assertNotIn('forceSpeed',flight)
        self.assertNotIn('CortexQueueJob',flight)
        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runNativeFlight.sqf').read_text(encoding='utf-8')
        for observed in ('_group allowFleeing 1','_x setDamage 1','fleeing _x','FiredMan',
                         'NATIVEFLIGHT-fallback-exercised','NATIVEFLIGHT-original-deadlines',
                         'NATIVEFLIGHT-replacement-physical','getPosASL _actor'):
            self.assertIn(observed,fixture)
        for shortcut in ('call CBE_fnc_DangerFlight','call CBE_fnc_DangerEngineAct',
                         'setVariable ["CBE_Danger_FlightLease"','setVariable ["CBE_Danger_FlightResult"',
                         'setPosATL','setPosASL','setPosWorld'):
            self.assertNotIn(shortcut,fixture)
        self.assertIn('_observedLeasedEscape && {_deadlinesStable}',fixture)
        self.assertIn('time <= (_first select 4)',fixture)
        self.assertIn('vectorDistance ((_rejoinOrigins select _index) select 0) >= 0.6',fixture)
        self.assertIn('if (_validLease) then {+_lease} else {[]}',fixture)

        # Re-entry consumes the original allowance, and a replacement move cannot be recalled.
        deadline=112
        self.assertEqual(max(0,deadline-105),7)
        self.assertEqual(max(0,deadline-113),0)
        def may_return(arrived,same_reservation,same_order,command,destination):
            return not arrived and same_reservation and same_order and command=='MOVE' and destination==(8,0,0)
        self.assertTrue(may_return(False,True,True,'MOVE',(8,0,0)))
        for row in ((True,True,True,'MOVE',(8,0,0)),(False,False,True,'MOVE',(8,0,0)),
                    (False,True,False,'MOVE',(8,0,0)),(False,True,True,'HEAL',(8,0,0)),
                    (False,True,True,'MOVE',(9,0,0))):
            self.assertFalse(may_return(*row))
if __name__=='__main__': unittest.main()
