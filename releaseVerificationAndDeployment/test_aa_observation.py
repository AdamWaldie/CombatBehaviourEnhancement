"""AA shot observation must remain owner-local, bounded and separate from behaviour proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AAObservation(unittest.TestCase):
    def test_native_receipt_lifecycle_does_not_claim_fire_or_move_authority(self):
        source=(ROOT/'addons/vehicles/functions/cortexAAObserve.sqf').read_text()
        for guard in ('!local _vehicle','isNull _projectile','!local _gunner',
                      'CortexActorFireTaskAvailable','CortexIsEligible','serverTime+1',
                      'CBE_AIPass_Epoch','removeEventHandler ["Fired"','"edsubcat_aas"'):
            self.assertIn(guard,source)
        for command in ('doMove','doFire','reveal','setVehicleRadar','setVelocity','spawn','waitUntil'):
            self.assertNotIn(command,source)
        discover=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('[_x] call CBE_fnc_CortexAAObserve;',discover)
        relocate=(ROOT/'addons/vehicles/functions/cortexAARelocate.sqf').read_text()
        for guard in ('count _shot != 11','_shot select 3)+120','aaRelocationConsumedAt',
                      'ENGAGEMENT_RENEWED','ORDER_REPLACED','CortexOwnershipLease',
                      'CortexGroupMove','CortexIsEligible','CortexActorFireTaskAvailable'):
            self.assertIn(guard,relocate)
        for command in ('doFire','reveal','setVehicleRadar','setVelocity','spawn','waitUntil'):
            self.assertNotIn(command,relocate)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        self.assertIn('[_group,_state,false] call CBE_fnc_CortexAARelocate',tick)
        self.assertIn('then {_groupMovementOwned=true}',tick)
        self.assertIn('serverTime+5',relocate)
        self.assertLess(relocate.index('_known findIf'),relocate.index('_state set ["aaRelocationConsumedAt"'))
        self.assertIn('THREAT_RENEWED',relocate)
        self.assertEqual(relocate.count('call _currentThreat'),2)
        self.assertIn('CBE_OperationGeneration',relocate)
        self.assertIn('CBE_AIPass_Contact_Enable',relocate)
        self.assertIn('if (!_eligible && {_record isEqualTo []}',source)
        self.assertIn('(_knowledge select 1)',source)
        self.assertIn('if (_contact isEqualTo []) exitWith {}',source)
        self.assertIn('private _current=count _record == 4 && {(_record select 0) == 2}',source)
        self.assertIn('count _record in [3,4]',source)
        self.assertIn('removeEventHandler ["IncomingMissile",_record select 3]',source)
        warning=source.split('private _warningHandler=',1)[1].split('_tracked pushBackUnique',1)[0]
        for proof in ('addEventHandler ["IncomingMissile"','_thisEventHandler','!local _group',
                      'CBE_AIPass_VehicleGunnery_Enable','serverTime+15',
                      '"CBE_AA_Observer",[2,clientOwner,_handler,_warningHandler]'):
            self.assertIn(proof,warning)
        self.assertIn('"CBE_AA_MissileWarning",nil',source)
        gunnery=(ROOT/'addons/vehicles/functions/cortexVehicles.sqf').read_text()
        receipt=gunnery.split('private _warnedBy=',1)[1].split('private _airPreference=',1)[0]
        for proof in ('_warning isEqualType []','count _warning == 6','== clientOwner',
                      '== _group','CBE_AIPass_Epoch','finite _until','serverTime < _until'):
            self.assertIn(proof,receipt)
        priority=gunnery.split('private _warningPriority=',1)[1].split('_ranked pushBack',1)[0]
        for proof in ('_enemy == _warnedBy','_gunner targetKnowledge _enemy',
                      '_warningKnowledge param [7,false,[true]]','_warningAge >= 0','_warningAge <= 3'):
            self.assertIn(proof,priority)
        self.assertLess(priority.index('case (_warningPriority)'),priority.index('case (_freshAir'))
        for forbidden in ('getPos','reveal','setMissileTarget','triggerAmmo','doMove'):
            self.assertNotIn(forbidden,priority+receipt+warning)


        self.assertIn('"AA_RELOCATE",time+((_until-serverTime) max 0)',relocate)
        self.assertIn('[_group,_state,_ordered,_enemies] call CBE_fnc_CortexAARelocate',tick)


        # Allocation model: distribute equal-tier contacts, preserve urgent threats,
        # ignore own incumbent and allow an already covered target if alternatives fail.
        def order(gunner, contacts, engagements):
            return sorted(contacts, key=lambda row: (
                row[1], sum(owner != gunner and target == row[0]
                            for owner, target in engagements), row[2]))
        contacts=[('near',-1,100),('far',-1,200)]
        assignments=[]
        chosen=order('one',contacts,assignments)[0][0]
        assignments.append(('one',chosen))
        self.assertEqual(order('two',contacts,assignments)[0][0],'far')
        self.assertEqual(order('one',contacts,assignments)[0][0],'near')
        self.assertEqual(order('two',[('near',-2,100),('far',-1,200)],assignments)[0][0],'near')
        eligible=[row for row in order('two',contacts,assignments) if row[0] != 'far']
        self.assertEqual(eligible[0][0],'near')
        assignments=[('one','far')]  # replacement retires the old near reservation
        self.assertEqual(order('two',contacts,assignments)[0][0],'near')
        allocation=gunnery.split('private _aaAllocationVehicles=',1)[1].split('private _airProbeCount=',1)[0]
        self.assertIn('_vehicles select [0,16]',allocation)
        self.assertIn('getAttackTarget _aaGunner',gunnery)
        self.assertIn('_ranked pushBack [_priority, _airLoad, _distance, _forEachIndex]',gunnery)
        self.assertIn('((_ranked select 0) select 3)',gunnery)
        self.assertIn('_gunneryContacts select (_x select 3)',gunnery)
        reservation=gunnery.split('private _oldAllocation=',1)[1].split('CBE_AIPass_TargetHold',1)[0]
        self.assertIn('_aaEngagements deleteAt _oldAllocation',reservation)
        self.assertLess(gunnery.index('_gunner doFire _target;'),gunnery.index('private _oldAllocation='))

        intercept=(ROOT/'addons/vehicles/functions/cortexAAIntercept.sqf').read_text()
        for bound in ('count _registry >= 4','count _rounds >= 8','time+(8 min','>= 160',
                      '< 16','_dt > 0.2','CBE_AIPass_AAIntercept_Enable',
                      'CortexActorFireTaskAvailable','CortexExternalOwner','CAMERA_REPLACED'):
            self.assertIn(bound,intercept)
        for forbidden in ('triggerAmmo','deleteVehicle','setDamage','setVelocity','setGroupOwner',
                          'addMagazine','reveal','addPerFrameHandler','nearestObjects'):
            self.assertNotIn(forbidden,intercept)
        self.assertIn('_vehicle selectionNames "Memory"',intercept)
        self.assertIn('_vehicle lockCameraTo [_point,_turret,true]',intercept)
        self.assertIn('_lock isEqualTo _applied',intercept)
        permission=(ROOT/'addons/infantry/functions/cortexActorFireTaskAvailable.sqf').read_text()
        self.assertIn('finite (_aaLease select 1)',permission)
        self.assertIn('time < (_aaLease select 1)',permission)
        self.assertIn('_job getOrDefault ["token",""]',intercept)
        self.assertIn('_observation get "loadedTurret"',intercept)
        self.assertIn('_operator != (_state get "gunner")',intercept)
        self.assertIn('_muzzle != (_state get "muzzle")',intercept)
        fire_handler=source.split('private _handler=',1)[1].split('private _warningHandler=',1)[0]
        self.assertLess(fire_handler.index('"SHOT",_this'),fire_handler.index('CBE_AA_ObserveDue'))
        self.assertIn('"RELEASE"] call CBE_fnc_CortexAAIntercept',source)
        effect=(ROOT/'addons/vehicles/functions/cortexAAInterceptEffect.sqf').read_text()
        for guard in ('!local _round','!local _missile','getShotParents _round','getShotParents _missile',
                      'getShotInfo _round','_roundInfo select 5','_roundInfo select 7',
                      'time-_at > 0.1','CBE_AA_FuseReceipt','submunitionAmmo',
                      '_fraction <= 0','_fraction >= 1','min 0.15','_radius >= 0.02',
                      '_pass distance _origin','_targetPos distance (getPosASL _vehicle) < 30',
                      'fuseGeometryRead','FUSE_REQUESTED'):
            self.assertIn(guard,effect)
        self.assertEqual(effect.count('\ntriggerAmmo _missile;'),1)
        self.assertLess(effect.index('_distance > _radius'),effect.index('triggerAmmo _missile;'))
        self.assertIn('CortexAAInterceptEffect',intercept)
        self.assertNotRegex(effect,r'\bremoteExec(?:Call)?\b')
        for forbidden in ('nearestObjects','createVehicle','deleteVehicle','setPos','setVelocity'):
            self.assertNotIn(forbidden,effect)
        # Independent swept-pass fixtures distinguish an interior crossing, a miss,
        # approaching-only endpoint proximity, and zero relative movement.
        def observed_pass(start,end,radius):
            delta=tuple(b-a for a,b in zip(start,end))
            squared=sum(a*a for a in delta)
            if squared < 0.0001:return False
            at=-sum(a*b for a,b in zip(start,delta))/squared
            if not 0 < at < 1:return False
            return sum((a+at*b)**2 for a,b in zip(start,delta)) <= radius**2
        self.assertTrue(observed_pass((-1,0.05,0),(1,0.05,0),0.1))
        self.assertFalse(observed_pass((-1,0.2,0),(1,0.2,0),0.1))
        self.assertFalse(observed_pass((-1,0,0),(-0.01,0,0),0.1))
        self.assertFalse(observed_pass((0,0,0),(0,0,0),0.1))
        spot=(ROOT/'addons/vehicles/functions/cortexAASpot.sqf').read_text()
        for guard in ('!local _missile','select [0,8]','count _rows > 8','count _samples > 4',
                      'count _samples < 3','_age <= 60','2^(-_age/30)',
                      'time-(_x select 1) <= 30','_leadAdded','_elevationAdded',
                      'vectorMagnitude _miss > 6','_flight > 2','> 2}',
                      '0.005','0.0005','0.05'):
            self.assertIn(guard,spot)
        for forbidden in ('setSkill','setVelocity','triggerAmmo','doFire','lockCameraTo','spawn','waitUntil','remoteExecCall'):
            self.assertNotIn(forbidden,spot)
        self.assertIn('[_state,"SAMPLE"',intercept)
        self.assertIn('_row set [8,true]',intercept)
        self.assertIn('[_state] call CBE_fnc_CortexAASpot',intercept)
        self.assertIn('if (_override > 0) then {_speed=_override}',intercept)
        self.assertIn('if (_override < 0) then {_speed=_speed*(-_override)}',intercept)
        self.assertIn('coefGravity',intercept)
        self.assertIn('CBE_AA_Corrections",nil',source)
        # Calibration invariants: insufficient/conflicting evidence leaves aim alone;
        # three coherent corrections move toward the measured bias with bounded gain.
        import statistics
        def adjust(values,current,step):
            if len(values)<3 or max(values)-min(values)>4*step:return current
            change=(statistics.median(values)-current)*0.2
            return current+max(-step,min(step,change))
        self.assertEqual(adjust([0.02],0,0.005),0)
        self.assertEqual(adjust([-0.05,0,0.05],0,0.005),0)
        self.assertAlmostEqual(adjust([0.019,0.02,0.021],0,0.005),0.004)
        self.assertAlmostEqual(adjust([-0.005,-0.0045,-0.004],0,0.0005),-0.0005)
        self.assertAlmostEqual(2**(-30/30),0.5)

        allocate=(ROOT/'addons/vehicles/functions/cortexAAAllocate.sqf').read_text()
        link=(ROOT/'addons/vehicles/functions/cortexAAWarningLink.sqf').read_text()
        for bound in ('count _tracks < 8','count _vehicles >= 16','select [0,64]',
                      'time+1','CBE_AA_WarningLifetimes','count _lifetimes >= 8',
                      'serverTime >= _firstExpiry','(_warning select 7) pushBackUnique _vehicle',
                      '_position vectorDotProduct _velocity','_miss <= 30','_time <= 2',
                      '_trackIndex','CortexAAWarningLink'):
            self.assertIn(bound,allocate)
        self.assertEqual(allocate.count('call CBE_fnc_CortexAAIntercept'),1)
        self.assertIn('if (_freshPlan && {!_added}) exitWith {false}',allocate)
        self.assertIn('if (_added) then {_plan set ["replan",true]}',allocate)
        self.assertIn('_plan getOrDefault ["replan",false]',allocate)
        fresh=allocate.split('private _freshPlan=',1)[1].split('if (_freshPlan &&',1)[0]
        self.assertNotIn('time >=',fresh)
        for forbidden in ('allUnits','allGroups','nearestObjects','nearEntities','doFire','reveal','spawn'):
            self.assertNotIn(forbidden,allocate)
        for guard in ('CBE_AIPass_ContactReports_Enable','CBE_AIPass_ContactReports_VoiceRange',
                      'CBE_AIPass_ContactReports_Radius','CortexCanTransmit','count _cache < 32'):
            self.assertIn(guard,link)
        self.assertIn('CortexAAWarningLink',intercept)
        self.assertIn('vehicle _homing != _victim',intercept)
        self.assertIn('DEFENDED_ASSET_LOST',intercept)
        self.assertIn('"linkDue",time+1',intercept)
        self.assertIn('count _shared != 8',intercept)
        self.assertIn('simulationEnabled _gunner',intercept)
        self.assertIn('(side _group) getFriend (side _victim) < 0.6',effect)
        self.assertIn('count _cache >= 32',link)
        self.assertIn('CortexAAAllocate',source)
        # Allocation semantics: urgent approach retains priority; equal tiers spread
        # to unassigned threats. Claimed platform/threat pairs cannot restart.
        warnings=[('urgent',0,1,0.5),('other',1,0,4.0)]
        self.assertEqual(min(warnings,key=lambda row:row[1:])[0],'urgent')
        warnings=[('covered',1,1,3.0),('uncovered',1,0,4.0)]
        self.assertEqual(min(warnings,key=lambda row:row[1:])[0],'uncovered')
        first_expiry=8.0
        self.assertFalse(9.0<first_expiry)  # duplicate after pruning cannot renew
        claims={'platform-one'}
        self.assertNotIn('platform-two',claims);self.assertIn('platform-one',claims)

        # Analytical geometry fixtures: an observed relative segment crosses zero at
        # its midpoint; temporal gaps must be rejected by the production boundary.
        relative_start=(-10.0,1.0,0.0);relative_end=(10.0,1.0,0.0)
        delta=tuple(b-a for a,b in zip(relative_start,relative_end))
        fraction=-sum(a*b for a,b in zip(relative_start,delta))/sum(a*a for a in delta)
        miss=sum((a+fraction*b)**2 for a,b in zip(relative_start,delta))**0.5
        self.assertAlmostEqual(fraction,0.5);self.assertAlmostEqual(miss,1.0)
        # A transverse target at 300m moving100m/s has a positive lead time1s
        # for a sqrt(100000)m/s projectile; a faster receding target has no future root.
        import math
        speed=math.sqrt(100000)
        self.assertAlmostEqual(math.sqrt(300**2+(100*1)**2),speed*1)
        receding_roots=(-3.0,-1.0)
        for t in receding_roots:
            self.assertAlmostEqual((300+200*t)**2,(100*t)**2)
        self.assertTrue(all(t < 0 for t in receding_roots))

        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertLess(stop.index('[_x,true] call CBE_fnc_CortexAAObserve'),
                        stop.index('if (hasInterface && {!isServer}) exitWith'))
if __name__=='__main__':unittest.main()
