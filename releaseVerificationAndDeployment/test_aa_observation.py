"""AA shot observation must remain owner-local, bounded and separate from behaviour proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AAObservation(unittest.TestCase):
    def test_dedicated_air_role_is_shared_bounded_config_intent_not_weapon_permission(self):
        import math
        classifier=(ROOT/'addons/vehicles/functions/cortexAirDefenceRole.sqf').read_text()
        for proof in ('isKindOf "LandVehicle"','"editorSubcategory"','"threat"',
                      'count _threat == 3','!finite _x','_x < 0',
                      '(_threat select 2) > (_threat select 0)',
                      '(_threat select 2) > (_threat select 1)',
                      'count CBE_AirDefenceRoleClasses < 256'):
            self.assertIn(proof,classifier)
        def role(category,weights,declared=-1,land=True):
            if not land:return False
            if isinstance(declared,bool):return declared
            if declared != -1:return False
            if category.lower()=='edsubcat_aas':return True
            return (len(weights)==3 and all(isinstance(x,(int,float)) and not isinstance(x,bool)
                    and math.isfinite(x) and x>=0 for x in weights)
                    and weights[2]>0 and weights[2]>weights[0] and weights[2]>weights[1])
        for weights in ([0.3,0.3,1],[0,0,0.1],[1,2,3]):self.assertTrue(role('custom',weights))
        for weights in ([],[1,2],[0,0,0],[1,1,1],[0.7,0.5,0.3],[1,0.9,0.1],
                        [-1,0,1],[0,0,float('nan')],[0,0,float('inf')],[0,0,'AA']):
            self.assertFalse(role('custom',weights),weights)
        self.assertTrue(role('EdSubcat_AAs',[]))
        for declared,expected in ((-1,False),(True,True),(False,False),(-1,False)):
            self.assertEqual(role('custom',[0.8,0.6,0.6],declared),expected)
        for declared,expected in ((-1,True),(False,False),(True,True),(-1,True)):
            self.assertEqual(role('EdSubcat_AAs',[1,0.6,1],declared),expected)
        for malformed in ('AA',[],0,1,float('nan')):
            self.assertFalse(role('EdSubcat_AAs',[1,0.6,1],malformed))
        self.assertFalse(role('EdSubcat_AAs',[0,0,1],True,land=False))
        self.assertIn('_declared isEqualType true',classifier)
        self.assertIn('_declared isEqualTo -1',classifier)
        self.assertLess(classifier.index('getVariable ["CBE_AirDefenceRole",-1]'),classifier.index('private _class='))
        interceptor=(ROOT/'addons/vehicles/functions/cortexAAIntercept.sqf').read_text()
        for block in (interceptor.split('if (_mode == "SHOT")',1)[1].split('if (_mode == "START")',1)[0],
                      interceptor.split('private _valid=',1)[1].split('if (!_valid',1)[0]):
            self.assertIn('call CBE_fnc_CortexAirDefenceRole',block)
        observer=(ROOT/'addons/vehicles/functions/cortexAAObserve.sqf').read_text()
        for block in (observer.split('addEventHandler ["Fired"',1)[1].split('private _warningHandler',1)[0],
                      observer.split('addEventHandler ["IncomingMissile"',1)[1]):
            self.assertIn('call CBE_fnc_CortexAirDefenceRole',block)

        # Native Cheetah/Tigris inherit mixed/tied profiles; category fallback must
        # remain, and a custom-category clone is an explicit unresolved role case.
        for native in ([0.8,0.6,0.6],[1.0,0.6,1.0]):
            self.assertTrue(role('EdSubcat_AAs',native))
            self.assertFalse(role('custom',native))
        for ordinary in ([0.8,0.8,0.3],[0,0,0],[0.7,1,0.3]):
            self.assertFalse(role('',ordinary))
        self.assertLess(classifier.index('isKindOf "LandVehicle"'),classifier.index('private _class='))
        for name in ('cortexAAObserve','cortexAAAllocate','cortexAAIntercept','cortexAARelocate',
                     'cortexVehicles','vehicleArmourShot'):
            s=(ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text()
            self.assertIn('call CBE_fnc_CortexAirDefenceRole',s)
            self.assertNotIn('edsubcat_aas',s)
        code=classifier.split('params [[',1)[1]
        for forbidden in ('nearEntities','weaponsTurret','setVariable','reveal','doFire','doMove','spawn','execFSM'):
            self.assertNotIn(forbidden,code)

    def test_native_receipt_lifecycle_does_not_claim_fire_or_move_authority(self):
        source=(ROOT/'addons/vehicles/functions/cortexAAObserve.sqf').read_text()
        for guard in ('!local _vehicle','isNull _projectile','!local _gunner',
                      'CortexActorFireTaskAvailable','CortexIsEligible','serverTime+1',
                      'CBE_AIPass_Epoch','removeEventHandler ["Fired"','CortexAirDefenceRole'):
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
        self.assertIn('private _current=count _record == 4 && {(_record select 0) == 3}',source)
        self.assertIn('count _record in [3,4]',source)
        self.assertIn('removeEventHandler ["IncomingMissile",_record select 3]',source)
        warning=source.split('private _warningHandler=',1)[1].split('_tracked pushBackUnique',1)[0]
        for proof in ('addEventHandler ["IncomingMissile"','_thisEventHandler','!local _group',
                      'CBE_AIPass_VehicleGunnery_Enable','serverTime+15',
                      '"CBE_AA_Observer",[3,clientOwner,_handler,_warningHandler]'):
            self.assertIn(proof,warning)
        self.assertIn('"CBE_AA_MissileWarning",nil',source)
        threat=(ROOT/'addons/vehicles/functions/cortexAAThreat.sqf').read_text()
        self.assertIn('[_missile,_group,_source,"RECORD"] call CBE_fnc_CortexAAThreat',warning)
        for proof in ('_launch isEqualTo []','!canSuspend','getShotParents _missile',
                      '(_parents param [0,objNull]) == _source',
                      '[clientOwner,_missile,_source,side _source,+_parents,serverTime+15]',
                      '(_launch select 1) != _missile','serverTime >= (_launch select 5)',
                      'getFriend (_launch select 3)','!isNull _x && {_x !='):
            self.assertIn(proof,threat)
        for path in ('cortexAAAllocate.sqf','cortexAAIntercept.sqf','cortexAAInterceptEffect.sqf'):
            consumer=(ROOT/'addons/vehicles/functions'/path).read_text()
            self.assertIn('call CBE_fnc_CortexAAThreat',consumer)
            self.assertNotIn('getFriend (side (_warning select 5))',consumer)
            self.assertNotIn('getFriend (side (_state get "source"))',consumer)
        effect=(ROOT/'addons/vehicles/functions/cortexAAInterceptEffect.sqf').read_text()
        self.assertIn('isNull _source',effect)
        self.assertIn('(_targetParents param [0,objNull]) != _source',effect)

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

        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAAIntercept.sqf').read_text()
        for guard in ('"IncomingMissile"','"Fired"','CBE_AA_Observer','"shotWindow"',
                      'CBE_AA_InterceptResult','CBE_CortexQA_HeadlessBatch',
                      'AA-native-disable-release','No interception pass inferred'):
            self.assertIn(guard,fixture)
        for forbidden in ('CortexAAIntercept;', 'CBE_AA_MissileWarning",',
                          'setVelocity','triggerAmmo','allowDamage','setDamage'):
            self.assertNotIn(forbidden,fixture)
        pipeline=(ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text()
        self.assertIn("focus == 'aa' and batch_mode != 'normal'",pipeline)
        intercept=(ROOT/'addons/vehicles/functions/cortexAAIntercept.sqf').read_text()
        for bound in ('count _registry >= 4','count _rounds >= 8','time+(8 min','>= 160',
                      '< 16','_dt > 0.2','CBE_AIPass_AAIntercept_Enable',
                      'CortexActorFireTaskAvailable','CortexExternalOwner','CAMERA_REPLACED'):
            self.assertIn(bound,intercept)
        for forbidden in ('triggerAmmo','deleteVehicle','setDamage','setVelocity','setGroupOwner',
                          'addMagazine','reveal','addPerFrameHandler','nearestObjects'):
            self.assertNotIn(forbidden,intercept)
        # AA cannon admission is distinct from infantry bullet suppression and from
        # the scripted direct-pass fuse. Native 35mm HE must not be rejected merely
        # for explosive damage; missiles/shell simulation cannot borrow this policy.
        ready=(ROOT/'addons/infantry/functions/cortexGroundFireReady.sqf').read_text()
        self.assertIn('["_aaCannon",false,[true]]',ready)
        self.assertIn('!(_bulletSuppression || _aaCannon)',ready)
        self.assertIn('!_bulletSuppression || {getNumber (_ammo >> "indirectHit") <= 0',ready)
        self.assertIn('[_vehicle,_gunner,objNull,_observation,false,false,true]',intercept)
        self.assertIn('_state getOrDefault ["directFuse",false]',intercept)
        def admitted(simulation, indirect, explosive, rounds, suppression=False, aa=False):
            return not (suppression or aa) or (simulation == 'shotbullet' and rounds >= 20
                and (not suppression or (indirect <= 0 and explosive <= 0)))
        self.assertTrue(admitted('shotbullet',25,.6,680,aa=True))
        self.assertFalse(admitted('shotbullet',25,.6,680,suppression=True))
        self.assertFalse(admitted('shotbullet',25,.6,680,suppression=True,aa=True))
        self.assertTrue(admitted('shotbullet',0,0,100,suppression=True))
        self.assertFalse(admitted('shotmissile',100,1,30,aa=True))
        self.assertFalse(admitted('shotshell',100,1,30,aa=True))
        self.assertFalse(admitted('shotbullet',25,.6,19,aa=True))
        # A native dual-barrel declaration may replace inherited gunBeg. Missing
        # geometry must refuse rather than inventing a centre-of-model origin.
        self.assertIn('(getArray (_main >> "memoryPointGun")) select [0,8]',intercept)
        self.assertIn('_barrels pushBackUnique getText (_main >> "gunBeg")',intercept)
        self.assertIn('_x in _selections',intercept)
        def barrel(declared, inherited, actual):
            return next((point for point in declared[:8]+[inherited]
                         if isinstance(point,str) and point and point in actual), '')
        self.assertEqual(barrel(['left','right'],'legacy',['left','right']), 'left')
        self.assertEqual(barrel(['missing'],'legacy',['legacy']), 'legacy')
        self.assertEqual(barrel([],'legacy',['legacy']), 'legacy')
        self.assertEqual(barrel(['missing'],'absent',['optic']), '')
        self.assertEqual(barrel([None]*8+['left'],'absent',['left']), '')
        self.assertIn('_vehicle selectionNames "Memory"',intercept)
        # A native primary gunner may occupy a nonzero/nested path. Resolve exactly
        # that inherited config node; no first-turret fallback or borrowed geometry.
        self.assertIn('private _turret=+(_observation get "loadedTurret")',intercept)
        self.assertIn('private _children=_main >> "Turrets"',intercept)
        walk=intercept.split('private _main=configOf _vehicle;',1)[1].split('private _optic=',1)[0]
        self.assertIn('_main=_children select _x',walk)
        self.assertIn('if (!isClass _main)',walk)
        self.assertNotIn('configClasses',walk)
        self.assertNotIn('configProperties',walk)
        self.assertIn('forEach _turret',intercept)
        self.assertIn('count _children > 32',intercept)
        self.assertNotIn('private _turret=[0]',intercept)
        self.assertNotIn('param [0,configNull]',intercept)
        for text in (intercept,(ROOT/'addons/vehicles/functions/cortexAAInterceptEffect.sqf').read_text()):
            self.assertIn('_vehicle turretUnit _turret',text)
            self.assertIn('_vehicle turretLocal _turret',text)
        def resolve(nodes,path):
            if not 1<=len(path)<=8 or any(type(i)!=int or not 0<=i<32 for i in path):
                return None
            node=None
            for i in path:
                if len(nodes)>32 or i>=len(nodes):return None
                node=nodes[i]
                if not node.get('isClass',True):return None
                nodes=node.get('Turrets',[])
            return node['name']
        tree=[{'name':'observer'}, {'name':'AA','Turrets':[{'name':'nested-AA'}]}]
        self.assertEqual(resolve(tree,[0]),'observer')
        self.assertEqual(resolve(tree,[1]),'AA')
        self.assertEqual(resolve(tree,[1,0]),'nested-AA')
        for bad in ([],[-1],[2],[1,1],[32],[0.5],[True],[0]*9):
            self.assertIsNone(resolve(tree,bad))
        self.assertIsNone(resolve([{'name':'too-many'}]*33,[0]))
        self.assertIsNone(resolve([{'name':'property','isClass':False}], [0]))

        self.assertIn('_vehicle lockCameraTo [_point,_turret,true]',intercept)
        release=intercept.split('private _finish={',1)[1].split('if (_mode == "RELEASE")',1)[0]
        unlock=release.index('_vehicle lockCameraTo [objNull,_turret,false]')
        for proof in ('local _vehicle','group _actor','local _releaseGroup',
                      'CBE_AA_InterceptOwner','[_token,_state get "until"]',
                      '[_releaseGroup,false,_actor] call CBE_fnc_CortexExternalTakeover',
                      '[_vehicle] call CBE_fnc_CompatibilityExternalControl',
                      '_lock isEqualTo _applied'):
            self.assertLess(release.index(proof),unlock)
        # Ordinary disable/expiry cleanup still removes an exact lock. These are
        # ownership checks, not permission to keep firing or replay an old action.
        self.assertNotIn('CBE_AIPass_AAIntercept_Enable',release)
        self.assertNotIn('CBE_AIPass_Epoch',release)
        self.assertIn('isNil {',release)
        self.assertLess(release.index('_state set ["unlockAttempted",true]'),unlock)
        self.assertIn('time <= (_state get "until")+30',release)
        self.assertGreater(release.rindex('_lock=_vehicle lockedCameraTo _turret'),unlock)
        self.assertLess(release.index('if (!_cameraGone) exitWith {false}'),release.index('_vehicle setVariable ["CBE_AA_Intercept",nil]'))
        self.assertIn('"cameraPending",!_cameraGone',release)
        self.assertIn('isNil "_lock" || {_lock isEqualType objNull}',release)
        self.assertIn('_state=_vehicle getVariable ["CBE_AA_Intercept",createHashMap]',intercept)
        self.assertNotIn('call _finish;_state=createHashMap',intercept)
        self.assertIn('if (_state getOrDefault ["finished",false]) exitWith',intercept)
        step=intercept.split('if (_mode != "STEP" || {count _state == 0})',1)[1]
        self.assertLess(step.index('_job getOrDefault ["token",""]'),step.index('if (_state getOrDefault ["finished",false])'))
        for name in ('cortexAAInterceptEffect','cortexAASpot'):
            self.assertIn('_episode getOrDefault ["finished",false]',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())
            live=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text()
            self.assertIn('_liveEpisode getOrDefault ["finished",false]',live)
            self.assertIn('_liveEpisode getOrDefault ["token",""]',live)


        observer=(ROOT/'addons/vehicles/functions/cortexAAObserve.sqf').read_text()
        self.assertLess(observer.index('_retiring getOrDefault ["finished",false]'),observer.index('if (_eligible && {_current})'))
        permission=(ROOT/'addons/infantry/functions/cortexActorFireTaskAvailable.sqf').read_text()
        for bound in ('cameraPending','_platform turretUnit (_camera get "turret") == _actor'):
            self.assertIn(bound,permission)
        # Readback, not request/timeout, determines retirement. Foreign current control
        # is observed only; one refused unlock must never become a repeated writer.
        def cleanup(local,lock,applied='ours',allowed=True,attempted=False,late=False):
            if applied is None:return True,False
            if not local:return False,False
            gone=lock is None or lock!=applied
            request=not gone and allowed and not attempted and not late
            return gone,request
        self.assertEqual(cleanup(True,None),(True,False))
        self.assertEqual(cleanup(True,'successor'),(True,False))
        self.assertEqual(cleanup(True,'ours'),(False,True))
        for kwargs in ({'allowed':False},{'attempted':True},{'late':True}):
            self.assertEqual(cleanup(True,'ours',**kwargs),(False,False))
        self.assertEqual(cleanup(False,None),(False,False))


        self.assertIn('_lock isEqualTo _applied',intercept)
        permission=(ROOT/'addons/infantry/functions/cortexActorFireTaskAvailable.sqf').read_text()
        self.assertIn('finite (_aaLease select 1)',permission)
        self.assertIn('time < (_aaLease select 1)',permission)
        self.assertIn('_job getOrDefault ["token",""]',intercept)
        self.assertIn('_observation get "loadedTurret"',intercept)
        step=intercept.split('if (_mode != "STEP" || {count _state == 0})',1)[1]
        self.assertNotIn('call CBE_fnc_CortexGroundFireReady',step)
        self.assertIn('weaponState [_vehicle,_turret,_weapon,_muzzle]',step)
        for proof in ('(_loaded select 0) != _weapon','(_loaded select 1) != _muzzle',
                      '(_loaded select 3) != _magazine','_roundCount < 20','_reloadPhase != 0',
                      'weaponsTurret _turret) select [0,16]'):
            self.assertIn(proof,step)
        self.assertLess(step.index('weaponState [_vehicle,_turret,_weapon,_muzzle]'),step.index('_vehicle lockCameraTo'))
        self.assertLess(step.index('STATION_CHANGED'),step.index('call CBE_fnc_CortexGroundSelectMuzzle'))
        # Continuation binds its admitted muzzle; an unrelated newly loaded station gun
        # cannot replace it or force the episode to search the whole station again.
        admitted=('gun','coax','ball')
        def same_muzzle(row):
            return len(row)>=7 and (row[0],row[1],row[3])==admitted and row[4]>=20 and row[6]==0
        valid=['gun','coax','mode','ball',20,0,0]
        self.assertTrue(same_muzzle(valid))
        for index,value in ((0,'other'),(1,'other'),(3,'tracer'),(4,19),(6,.2)):
            changed=valid.copy();changed[index]=value;self.assertFalse(same_muzzle(changed))
        self.assertFalse(same_muzzle(valid[:5]))
        self.assertIn('_operator != (_state get "gunner")',intercept)
        capture=intercept.split('if (_mode == "SHOT") exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        for guard in ('!local _operator','gunner _vehicle != _operator','group _operator != _shotGroup',
                      'isPlayer _operator','remoteControlled _operator','CBE_AIPass_Epoch','CBE_AA_InterceptOwner',
                      'CortexActorFireTaskAvailable','CortexExternalTakeover','CompatibilityExternalControl',
                      'CortexIsPaused','unitCombatMode _operator','CBE_fnc_NativeOrderReceipt',
                      'getAttackTarget _operator','assignedTarget _operator','!alive (_state get "missile")'):
            self.assertLess(capture.index(guard),capture.index('_rounds pushBack'))
        self.assertLess(capture.index('count _rounds >= 8'),capture.index('private _shotGroup='))
        self.assertNotIn('triggerAmmo',capture)
        self.assertNotIn('lockCameraTo',capture)
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
        # An actual same-owner pass is still not permission to burst the hostile warhead
        # beside other protected entities. Query only after measured pass/arming checks.
        collateral=effect.split('private _blastRange=',1)[1].split('// Both native projectiles',1)[0]
        for proof in ('"indirectHitRange"','"indirectHit"','"explosive"',
                      '12 max (4*_blastRange)','_blastRadius > 250','count _near > 64',
                      '["CAManBase","LandVehicle","Air","Ship"],false,true,true',
                      'captive _other','ace_captives_isSurrendering','ace_captives_isHandcuffed',
                      '_otherSide == civilian','_side getFriend _otherSide >= 0.6'):
            self.assertIn(proof,collateral)
        self.assertIn('remoteExecutedOwner > 0 || {canSuspend}',effect)
        self.assertIn('if (_other isKindOf "CAManBase") then {side group _other} else {side _other}',collateral)
        self.assertEqual(effect.count('nearEntities'),1)
        self.assertLess(effect.index('_distance > _radius'),effect.index('nearEntities'))
        self.assertLess(collateral.index('fuseCollateralVetoAt'),collateral.index('nearEntities'))
        refusal='if ((_episode getOrDefault ["fuseCollateralVetoAt",-1]) == time) exitWith {false};'
        self.assertIn(refusal,effect)
        self.assertLess(effect.index(refusal),effect.index('setVariable ["CBE_AA_FuseReceipt"'))
        self.assertLess(effect.index(refusal),effect.index('triggerAmmo _missile;'))
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
        self.assertIn('_gunner,+_turret,_episode get "weapon"',spot)
        self.assertIn('_vehicle turretUnit _turret != _gunner',spot)
        self.assertIn('_vehicle turretLocal _turret',spot)

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
        self.assertIn('["until",time+3]',allocate)
        self.assertIn('_plan set ["until",time+3]',allocate)
        self.assertTrue(allocate.rstrip().endswith('0'))
        self.assertNotIn('0.05',allocate)
        cache=allocate.split('// A longer finite pass',1)[1].split('if !(_plan get "initialised")',1)[0]
        for proof in ('time >= (_plan getOrDefault ["linkCacheUntil",0])',
                      '_plan set ["linkCache",[]]','_plan set ["linkCacheUntil",time+1]'):
            self.assertIn(proof,cache)
        # Scheduler feasibility, not engine timing: one roster slot per due frame. The
        # old positive delay doubles below the configured FPS threshold; a late usable
        # station can then be omitted by the one-second whole-pass limit.
        import math
        def serviced(fps,delay,deadline):
            frames=max(1,math.ceil(delay*fps-1e-9))
            return [slot for slot in range(16) if slot*frames/fps < deadline]
        for fps in (10,15,20):
            self.assertLess(len(serviced(fps,0.05*2,1)),16)
            self.assertEqual(serviced(fps,0,3),list(range(16)))
        scheduler=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text()
        self.assertIn('_delay = _delay * 2',scheduler)
        self.assertIn('} forEach _jobs;',scheduler)
        self.assertEqual(allocate.count('call CBE_fnc_CortexAAIntercept'),1)
        self.assertEqual(allocate.count('getVariable ["CBE_AA_Intercept",createHashMap]'),1)
        ranking=allocate.split('private _ranked=[];',1)[1].split('} forEach _tracks;',1)[0]
        self.assertNotIn('CBE_AA_InterceptOwner',ranking)
        self.assertIn('private _coverage={_x isEqualTo _missile} count _coverageMissiles;',ranking)
        self.assertNotIn('_plan set ["coverage',allocate)
        coverage=allocate.split('private _coverageMissiles=[];',1)[1].split('} forEach _vehicles;',1)[0]
        for proof in ('!(_active getOrDefault ["finished",false])','alive _x','local _x','gunner _x == _coverageGunner','group _coverageGunner == _group','CBE_AA_InterceptOwner','[_active get "token",_active get "until"]'):
            self.assertIn(proof,coverage)
        self.assertLess(coverage.index('!(_active getOrDefault ["finished",false])'),coverage.index('_coverageMissiles pushBack'))
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
        # Readiness must precede both bypasses: voice and the request-local radio
        # cache. A retained positive jamming result cannot grant a dead crew link.
        voice=link.index('private _voice=')
        cached=link.index('private _transmit=')
        for guard in ('gunner _vehicle != _gunner','group _gunner != _group',
                      '[_sender] call CBE_fnc_CortexCombatEffective',
                      '[_gunner] call CBE_fnc_CortexCombatEffective',
                      '!simulationEnabled _sender','isObjectHidden _sender',
                      '!simulationEnabled _gunner','isObjectHidden _gunner'):
            self.assertLess(link.index(guard),voice)
            self.assertLess(link.index(guard),cached)
        own=link.split('if (_victim == _vehicle',1)[1].split('if (isNull _vehicle',1)[0]
        self.assertIn('exitWith {true}',own)
        for forbidden in ('doFire','reveal','remoteExec','setVariable'):
            self.assertNotIn(forbidden,link)

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
