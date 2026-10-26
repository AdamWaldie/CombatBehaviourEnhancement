"""Shared solid/gate observation wiring; no physical detour or braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGeometryTests(unittest.TestCase):
    def test_geometry_is_one_bounded_live_observation_without_helpers(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text().split('params [[',1)[1]
        self.assertEqual(s.count('lineIntersectsSurfaces'),2)
        self.assertIn('call CBE_fnc_DrivingHullInterval',s)
        self.assertEqual(s.count('modelToWorldWorld'),1)  # origin; body span uses shared four transforms
        self.assertNotIn('worldToModel',s)
        self.assertIn('["_travelDirection",1,[0]]',s)
        self.assertIn('private _standOff=[6,2] select (_travelDirection < 0)',s)
        self.assertIn('private _room=(_gap-_standOff) max 0',s)
        self.assertIn('vectorDir _vehicle) vectorMultiply _travelDirection',s)
        self.assertIn('if (!(_travelDirection in [-1,1])) exitWith {_unavailable}',s)
        # Reversing both horizontal body axes keeps the frame right-handed and
        # places the probe beyond the true asymmetric rear, never the front bumper.
        own_y=(-5,3)
        rear_edge=max(-own_y[0],-own_y[1])
        self.assertEqual(rear_edge,5)
        rear_world=-(rear_edge+.2+8)
        self.assertAlmostEqual(rear_world,-13.2)
        self.assertLess(rear_world,own_y[0])
        self.assertIn('(_modelPoints select 0) call _pointWorld',s)
        self.assertIn('[_edge+_side*_reach,_toY,_z] call _pointWorld',s)
        self.assertIn('_supportEnd call _pointBody',s)
        self.assertIn('if (count _ownHull != 6) exitWith {_unavailable}',s)
        self.assertIn('if (!finite _bodySpeed) exitWith {_unavailable}',s)
        self.assertIn('[0,objNull,0,time,0,"UNAVAILABLE",[],[],[]]',s)
        # Independent rigid-frame oracle: a metre horizon must remain that length
        # under native scale, pitch and roll; only the original body extents scale.
        import math
        def basis(pitch,roll):
            p,r=map(math.radians,(pitch,roll));c,t=math.cos(p),math.sin(p)
            f=(0,c,t); side=(math.cos(r),math.sin(r)*t,-math.sin(r)*c)
            up=(-math.sin(r),math.cos(r)*t,-math.cos(r)*c)
            # Select up so side = forward cross up, preserving a right-handed frame.
            up=tuple(-x for x in up)
            return side,f,up
        def point(v,axes,origin):
            return tuple(origin[i]+sum(v[j]*axes[j][i] for j in range(3)) for i in range(3))
        def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
        for scale in (.5,1,2):
            for pitch,roll in ((0,0),(25,0),(-20,15)):
                axes=basis(pitch,roll);origin=(500,1000,40)
                front=5*scale+0.25; width=1.5*scale+0.25; height=.5*scale+.45
                start=point((width,front,height),axes,origin)
                end=point((width,front+40,height),axes,origin)
                self.assertAlmostEqual(distance(start,end),40)
                self.assertAlmostEqual(distance(start,point((width,front+.7,height),axes,origin)),.7)
                relative=tuple(end[i]-origin[i] for i in range(3))
                body=tuple(sum(relative[i]*axis[i] for i in range(3)) for axis in axes)
                self.assertAlmostEqual(body[1],front+40)
                # Old modelToWorld application multiplied the horizon and contact margin too.
                self.assertAlmostEqual(distance(start,end)*scale,40*scale)
                k=.02; length=6; angle=k*length
                station=((1-math.cos(angle))/k,math.sin(angle)/k,0)
                arc_start=point((0,0,0),axes,origin); arc_end=point(station,axes,origin)
                self.assertAlmostEqual(distance(arc_start,arc_end),2*math.sin(angle/2)/k)
                # The support-profile 0.3m threshold is a physical body-axis value.
                raised=point((0,6,.4),axes,origin)
                delta=tuple(raised[i]-origin[i] for i in range(3))
                self.assertAlmostEqual(sum(delta[i]*axes[2][i] for i in range(3)),.4)
        for required in ('true,4,"GEOM","NONE"','[_left,(_left+_right)*0.5,_right]',
                         'forEach _heights','max 25 min 600','getPosWorld _object','vectorUp _object',
                         '(_normal select 2) < 0.7','_object isKindOf "LandVehicle"'):
            self.assertIn(required,s)
        # Optional contact sampling is bounded and read-only; ordinary callers retain defaults.
        for required in ('["_nearContact",false,[true]]','if (_nearContact) then',
                         '_linear < (1/3.6)','_angular < 0.01','forEach [-1,1]',
                         'forEach [0.3,0.6]',
                         '[[_frontY-0.1,_frontY+0.55,0.7],[_quarter,_quarter,0.6],[0,0,0.6]]',
                         'count _probeObjects >= 16','call CBE_fnc_DrivingBypassObstacleAvailable',
                         '(_leftContact isEqualTo []) != (_rightContact isEqualTo [])',
                         '_probeSide == 0 && {_isGate}',
                         '!isNull _object && {_kind == "STATIC"}'):
            self.assertIn(required,s)
        self.assertEqual(2*2*3,12)
        self.assertEqual(3*3*3+12,39)
        self.assertEqual(3*3*3+12+3*3+3*2,54)
        for required in ('count _supportPath == 3','> 0.3','count _levels != 1',
                         '_point vectorAdd [0,0,0.75]','_point vectorAdd [0,0,-0.75]',
                         '<= 0.4','if (_supported) then','vectorAdd [0,0,0.45]'):
            self.assertIn(required,s)
        self.assertNotIn('getTerrainHeight',s)
        # Wrong-floor terrain, roofs/undersides and multiple plausible levels cannot
        # provide a low-row support profile. This is analytic filtering, not PhysX proof.
        def support(path_z, surfaces):
            candidates=[z for z,normal_z in surfaces if normal_z>=0.7 and abs(z-path_z)<=0.4]
            return candidates[0] if len(candidates)==1 else None
        self.assertEqual(support(10,[(10,1),(0,1)]),10)
        self.assertIsNone(support(10,[(0,1)]))
        self.assertIsNone(support(10,[(10,-1)]))
        self.assertIsNone(support(10,[(9.9,1),(10.1,1)]))
        self.assertIsNone(support(10,[(10,0.5)]))
        for forbidden in ('createVehicle','allMissionObjects','allDead','spawn','waitUntil','setVariable',
                          'setVelocity','doMove','forceSpeed','animateSource','animationSourcePhase'):
            self.assertNotIn(forbidden,s)
    def test_support_filter_keeps_downward_undersides_as_obstructions(self):
        import re
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text(encoding='utf-8')
        # Read the actual production predicate, including a possible absolute-value regression.
        match=re.search(r'&& \{(?P<absolute>abs )?\(_normal select 2\) < (?P<cutoff>[0-9.]+)\}',s)
        self.assertIsNotNone(match)
        cutoff=float(match.group('cutoff'))
        def blocks(z):
            return (abs(z) if match.group('absolute') else z) < cutoff
        for label,z,expected in [('level support',1,False),('gentle uphill support',0.9,False),
                                 ('vertical wall',0,True),('sloping underside',-0.8,True),
                                 ('horizontal underside',-1,True)]:
            with self.subTest(surface=label):
                self.assertEqual(blocks(z),expected)

    def test_gate_adapter_preserves_only_gate_result_and_barriers_need_sources(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateCap.sqf').read_text()
        self.assertIn('call CBE_fnc_DrivingGeometryCap) select 0',s)
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        self.assertIn('_gateClasses getOrDefault',s)
        self.assertIn('for "_index" from 1 to 8',s)
        self.assertIn('private _sourceConfig=configOf _object >> "AnimationSources"',s)
        self.assertIn('isClass (_sourceConfig >> _x)',s)
        candidates=s.split('if (!_isGate && {',1)[1].split('_gateClasses set',1)[0]
        for native_class in ('Wall','Fence'):
            self.assertIn('_object isKindOf "'+native_class+'"',candidates)
        self.assertNotIn('isKindOf "House"',candidates)
        self.assertLess(candidates.index('isClass (_sourceConfig >> _x)'),candidates.index('exitWith {_isGate=true}'))
        self.assertIn('[_gateObservation,_solidObservation]',s)
    def test_solid_constraints_reuse_existing_writers_and_fsm_queue(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        qualification=ordinary.split('private _cornerProbe=',1)[1].split('private _geometry=',1)[0]
        for required in ('!_reverseLeg','!_crewBoardingHold','!_queueHold','!_queueNativeActive',
                         '!_queueCrossing','_recoveryOwned','(_state param [6,0]) == 1',
                         '["kind",""]) == "REFRESH"','["bypassSpent",false]) isEqualTo false',
                         'serverTime >= _cornerStarted+3','call _stationary',
                         '["SAFE","AWARE"]','getSuppression _driver <= 0.1',
                         'CBE_DrivingPass_Work','CBE_DrivingCorridor_Work',
                         'CBE_DrivingBypass_Work','call _mayRecoverOrdinaryRoute'):
            self.assertIn(required,qualification)
        self.assertIn('[_vehicle,_capMps,false,_curveHint,_cornerProbe,_travelDirection]',ordinary)
        self.assertNotIn('_cornerProbe',convoy)
        self.assertEqual(ordinary.count('call CBE_fnc_DrivingGeometryCap'),1)
        self.assertEqual(convoy.count('call CBE_fnc_DrivingGeometryCap'),2)
        self.assertIn('_traffic=_obstacleObservation select [0,5]',ordinary)
        self.assertIn('_leadTraffic=_leadObstacle select [0,5]',convoy)
        self.assertIn('_traffic=_vehicleObstacle select [0,5]',convoy)
        for path in ('drivingOperation','convoyOperation'):
            self.assertIn('""OBSTACLE""',(ROOT/f'addons/main/fsm/{path}.fsm').read_text())
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertIn('CBE_DrivingAssist_Obstacle",nil',release)

    def test_turn_prediction_is_bounded_read_only_and_keeps_absolute_hull_rows(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        for marker in ('angularVelocityModelSpace _vehicle','_velocity <= 1','_velocity*2.5',
                       '70/57.2957795','>= 3','0.5*_bendLength,_bendLength,_horizon',
                       'count _stations-1','_front*sin _angle','_width*sin _angle',
                       '_segmentStart+_fraction*(_segmentEnd-_segmentStart)','_from vectorDistance _to'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),2)
        self.assertNotIn('setAngularVelocity',s)
        self.assertNotIn('setVariable',s.split('params [[',1)[1])

    def test_track_measurement_resets_at_ownership_route_and_motion_boundaries(self):
        s=(ROOT/'addons/vehicles/functions/drivingTurnTrack.sqf').read_text()
        for marker in ('clientOwner','driver _vehicle','effectiveCommander _vehicle',
                       '_forward <= 1','_previous select 0) isNotEqualTo _identity',
                       'time-(_previous select 2) > 6','_distanceSquared >= 9',
                       'time-(_previous select 2) >= 1.5','abs _curvature < 0.004',
                       'vectorDotProduct _bodySide','vectorDotProduct _bodyForward','"BODY_METRES"'):
            self.assertIn(marker,s)
        self.assertNotIn('worldToModel',s)
        self.assertIn('["_travelDirection",1,[0]]',s)
        self.assertIn('!(_travelDirection in [-1,1])',s)
        self.assertIn('clientOwner,"BODY_METRES",_travelDirection]',s)
        self.assertIn('(vectorNormalized vectorDir _vehicle) vectorMultiply _travelDirection',s)
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('ownerEpoch",-1]],_travelDirection] call CBE_fnc_DrivingTurnTrack',assist)
        self.assertIn('if (_nativeReverse || {count _nativeHint != 4}) then {[_turn select 0]}',assist)
        # Rotating both planar axes by pi reverses signed chord curvature,
        # without changing its physical radius or displacement sampling threshold.
        for side,along in ((2,-5),(-2,-5),(0,-4),(0.5,-3)):
            forward=2*side/(side*side+along*along)
            rear_side,rear_along=-side,-along
            rear=2*rear_side/(rear_side*rear_side+rear_along*rear_along)
            self.assertAlmostEqual(rear,-forward)
            self.assertAlmostEqual(rear_side**2+rear_along**2,side**2+along**2)
        self.assertNotEqual(('route','BODY_METRES',1),('route','BODY_METRES',-1))
        # A fixed physical chord has the same curvature for every object scale.
        x,y=2.0,6.0
        expected=2*x/(x*x+y*y)
        for scale in (.5,1,2):
            self.assertAlmostEqual(2*x/(x*x+y*y),expected)
            old_x,old_y=x/scale,y/scale
            old=2*old_x/(old_x*old_x+old_y*old_y)
            self.assertAlmostEqual(old,expected*scale)
            if scale!=1:self.assertNotAlmostEqual(old,expected)
            # Old model-unit displacement could postpone or prematurely take a sample.
            old_distance=(2.0/scale)**2
            self.assertEqual(old_distance>=9,scale==.5)
        for forbidden in ('setVariable','spawn','waitUntil','doMove','forceSpeed','lineIntersectsSurfaces'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        for name in ('drivingAssistStart','convoyTick'):
            self.assertIn('call CBE_fnc_DrivingTurnTrack',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_ordinary_measurements_are_per_vehicle_and_prune_departed_roster(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('private _geometryTracks=createHashMap',s)
        self.assertIn('_priorTracks getOrDefault [netId _x,[]]',s)
        self.assertIn('_geometryTracks getOrDefault [netId _vehicle,[]]',s)
        self.assertIn('_geometryTracks set [netId _vehicle,_turn select 1]',s)
        self.assertNotIn('getOrDefault ["geometryTrack",[]]',s)

    def test_native_path_hint_is_fresh_local_bounded_and_not_a_movement_writer(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        for marker in ('"PathCalculated"','_path select [0,64]','_thisEventHandler',
                       'removeEventHandler','_expectedRevision','time-(_segment select 1) > 5',
                       'expectedDestination _driver','expectedDestination _operator',
                       '_distance < _nearDistance','_distance >= 3','_distance <= 12','(_target select 1) > 1','_walked >= 6','_oldBinding select 3'):
            self.assertIn(marker,s)
        for forbidden in ('doMove','setDriveOnPath','forceSpeed','calculatePath','createAgent','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        self.assertNotRegex(s.split('params [[',1)[1],r'setVariable\s*\[[^\n]*,\s*true\s*\]')
        for name in ('drivingAssistRelease','convoyReleaseLocal'):
            self.assertIn('call CBE_fnc_DrivingNativePathWatch',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_native_path_lookahead_is_distance_bounded_for_dense_and_sparse_nodes(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text(encoding='utf-8')
        selection=s.split('// Native paths may use dense nodes.',1)[1]
        for marker in ('_nearPoint=+_closest','for "_i" from (_nearIndex+1) to (count _nodes-1)',
                       '_advance=_length min (6-_walked)','_delta vectorMultiply (_advance/_length)',
                       '_floorLost','_distance >= 3','_distance <= 12'):
            self.assertIn(marker,s)
        self.assertNotIn('_nearIndex+3',selection)
        self.assertNotIn('worldToModel',selection)
        self.assertIn('_targetRelative vectorDotProduct _bodySide',selection)
        self.assertIn('_targetRelative vectorDotProduct _bodyForward',selection)
        for guard in ('private _directionOnly=_targetASL isEqualTo []','_walked < 0.5','_walked >= 3',
                      '_distance < 0.5','_distance >= 3','(_target select 1) > 0.5',
                      '[0,false,[],-1,1]'):
            self.assertIn(guard,selection)
        self.assertLess(selection.index('if (_directionOnly) exitWith'),selection.index('private _distanceSquared='))
        # Short native legs can establish direction without manufacturing a bend.
        def short_direction(walked,distance,forward,floor=True):
            return floor and .5<=walked<3 and .5<=distance<3 and forward>.5
        self.assertTrue(short_direction(2,2,2))
        self.assertFalse(short_direction(.4,.4,.4))
        self.assertFalse(short_direction(2,2,-2))
        self.assertFalse(short_direction(2,2,2,False))
        for name in ('drivingAssistStart','convoyTick'):
            consumer=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text()
            self.assertIn('count _nativeHint != 4',consumer)
        self.assertLess(selection.index('_floorLost ||'),selection.index('private _targetRelative='))
        # Prior next-three-node admission rejects these valid half-metre forward samples.
        dense=[i*0.5 for i in range(1,64)]
        self.assertLess(max(dense[:3]),3)
        self.assertIn(6,dense)
        # A single sparse segment also spans the desired lookahead; interpolation is required.
        self.assertLess(6,20)
        self.assertIn('_path select [0,64]',s)
        self.assertIn('_supportPath=[+_nearPoint]',s)
        self.assertIn('(3-_walked)/_length',s)
        self.assertIn('_walked >= 6 && {count _supportPath == 2}',s)
        self.assertIn('true,_supportPath,_nativeGrade]',s)
        self.assertIn('_nativeGrade=_nativeGrade max (abs (_delta select 2)/_length)',selection)
        for name,variable in (('drivingAssistStart','_capMps'),('convoyTick','_limit')):
            consumer=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text()
            grade=consumer.split('private _nativeGrade=_nativeHint param [3,-1,[0]];',1)[1].split('};',2)[0]
            self.assertIn('finite _nativeGrade',grade)
            self.assertIn('_nativeGrade > 0.2',grade)
            self.assertIn('_nativeGrade > 0.12',grade)
            self.assertIn(variable+'='+variable+' min',grade)
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        lead=convoy.split('private _leadNativeGrade=',1)[1].split('private _leadGeometry=',1)[0]
        for proof in ('_leadNativeHint param [3,-1,[0]]','finite _leadNativeGrade',
                      '_leadNativeGrade > 0.2','_leadLimit=_leadLimit min 18',
                      '_leadNativeGrade > 0.12','_leadLimit=_leadLimit min 25',
                      'pushBack ["nativeGrade",_leadLimit]'):
            self.assertIn(proof,lead)
        for forbidden in ('forceSpeed','limitSpeed','nearEntities','lineIntersects','setVariable'):
            self.assertNotIn(forbidden,lead)
        self.assertLess(convoy.index('private _leadNativeGrade='),convoy.index('private _leadGeometry='))
        geometry=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        self.assertIn('count _measured in [1,2,3,4]',geometry)
        # Existing road policy applies symmetrically to observed climbs/descents;
        # unknown/level metadata cannot raise a stricter independent speed ceiling.
        def ceiling(requested,grade):
            return min(requested,18 if grade>.2 else 25 if grade>.12 else requested)
        for grade,expected in ((-1,50),(0,50),(.12,50),(.13,25),(.2,25),(.21,18)):
            self.assertEqual(ceiling(50,grade),expected)
            self.assertLessEqual(ceiling(5,grade),5)
        self.assertEqual(abs(-1.5)/6,.25)
        self.assertEqual(abs(.125)/.5,abs(1.5)/6)

    def test_native_path_subscription_expires_before_copy_and_feature_off_retires_old_revision(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        event=s.split('private _id=_driver addEventHandler',1)[1].split('_record=[_group',1)[0]
        for marker in ('CBE_DrivingNativePath_ValidUntil','CortexFeatureEnabled',
                       'bis_fnc_moduleRemoteControl_owner','CortexExternalOwner'):
            self.assertLess(event.index(marker),event.index('_path select [0,64]'))
        self.assertIn('[_unit,effectiveCommander _vehicle] findIf',event)
        self.assertIn('[_driver,_operator] findIf',s)
        self.assertIn('"CBE_DrivingNativePath_ValidUntil",time+6',s)
        self.assertIn('"CBE_DrivingNativePath_ValidUntil",nil',s)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('["CONVOY"],true] call CBE_fnc_DrivingNativePathWatch',tick)
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('["CONVOY"],true,_navigation getOrDefault ["revision",-1]',release)

    def test_native_path_crossing_refuses_disconnected_near_stretches(self):
        source=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text(encoding='utf-8')
        for marker in ('_nearRuns=0','_inNearRun=false','_distance <= 3',
                       'if (!_inNearRun) then {_nearRuns=_nearRuns+1}',
                       '_nearIndex < 0 || {_distance < _nearDistance}',
                       '_nearIndex < 0 || {_nearRuns > 1}'):
            self.assertIn(marker,source)
        # Dense consecutive near segments are one stretch; leaving and returning is ambiguous.
        def stretches(flags):
            return sum(flag and (i==0 or not flags[i-1]) for i,flag in enumerate(flags))
        self.assertEqual(stretches([False,True,True,True,False]),1)
        self.assertEqual(stretches([True,True,False,False,True]),2)
        self.assertEqual(stretches([False]*63),0)
        # A self-crossing polyline has two separate stretches near the origin.
        # Its later northbound return must not replace the first northeast approach.
        import math
        def distance_to_segment(a,b):
            dx,dy=b[0]-a[0],b[1]-a[1]
            fraction=max(0,min(1,-(a[0]*dx+a[1]*dy)/(dx*dx+dy*dy)))
            return math.hypot(a[0]+fraction*dx,a[1]+fraction*dy)
        crossing=[(-10,-5),(8,4),(20,20),(0,-10),(0,8)]
        flags=[distance_to_segment(a,b)<=3 for a,b in zip(crossing,crossing[1:])]
        self.assertEqual(flags,[True,False,False,True])
        self.assertEqual(stretches(flags),2)
    def test_convoy_bypass_relaxation_rejects_multiple_capture_clusters_and_wrong_floor(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=s.split('private _bypassLegClear=false',1)[1].split('if (!_bypassLegClear',1)[0]
        self.assertIn('count _committed <= 11',gate)
        self.assertIn('abs ((_origin select 2)-(_pointASL select 2)) <= 1.5',gate)
        self.assertIn('if (_captureRuns != 1) then {_nearest=-1}',gate)
        self.assertLess(gate.index('_captureRuns != 1'),gate.index('call CBE_fnc_DrivingPathGeometry'))
        self.assertNotIn('doMove',gate)
        self.assertNotIn('setDriveOnPath',gate)
        def runs(points):
            flags=[(x*x+y*y)**0.5<4 and abs(z)<=1.5 for x,y,z in points]
            return sum(value and (i==0 or not flags[i-1]) for i,value in enumerate(flags))
        self.assertEqual(runs([(0,1,0),(0,5,0),(5,5,0),(0,0,0)]),2)
        self.assertEqual(runs([(0,1,0),(0,2,0),(0,5,0)]),1)
        self.assertEqual(runs([(0,0,5),(0,1,5)]),0)


class ConvoyOrderedCaptureTests(unittest.TestCase):
    """Arithmetic route cases, not native steering or physical acceptance."""
    @staticmethod
    def capture(trail, pose, previous=None):
        import math
        previous=pose if previous is None else previous
        sweep=[b-a for a,b in zip(previous,pose)]
        squared=sweep[0]**2+sweep[1]**2
        candidates=[]
        for i,point in enumerate(trail):
            t=max(0,min(1,sum((point[k]-previous[k])*sweep[k] for k in (0,1))/squared)) if squared>.01 else 1
            near=[previous[k]+t*sweep[k] for k in range(3)]
            if math.dist(near[:2],point[:2])>=18 or abs(near[2]-point[2])>1.5:
                break
            candidates.append((math.dist(pose[:2],point[:2]),i))
        return min(candidates)[1] if candidates else -1

    def test_loop_return_does_not_skip_untravelled_middle(self):
        trail=[(0,5,0),(0,10,0),(0,15,0),(10,15,0),(10,0,0),(1,0,0),(1,-10,0)]
        self.assertEqual(self.capture(trail,(0,0,0)),0)
        # A nearer return point must remain unavailable beyond an uncaptured bend.
        self.assertEqual(self.capture([(0,5,0),(0,25,0),(1,0,0)],(0,0,0)),0)

    def test_observed_straight_travel_can_pass_multiple_samples(self):
        trail=[(0,y,0) for y in range(0,61,5)]
        self.assertEqual(self.capture(trail,(0,30,0),(0,0,0)),6)
        # A missing sweep cannot justify skipping the first now-distant point.
        self.assertEqual(self.capture(trail,(0,30,0)),-1)

    def test_height_separates_overpass_and_interpolates_observed_grade(self):
        self.assertEqual(self.capture([(0,0,6),(0,5,6)],(0,0,0)),-1)
        self.assertEqual(self.capture([(0,y,y/5) for y in range(0,31,5)],(0,30,6),(0,0,0)),6)

    def test_production_uses_contiguous_capture_and_only_next_join_point(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        gate=s.split('// Advance only through a contiguous prefix',1)[1].split('if (_nearest >= 0)',1)[0]
        for marker in ('time-(_sample select 1) <= 3','vectorDistance _pose <= 100',
                       '_capture distance2D _pointASL >= 18','> 1.5}) exitWith {}',
                       '_progress set [11,[+_pose,time]]',
                       'for "_j" from _start to (_start min _frontIndex)',
                       'abs ((_point select 2)-(_origin select 2)) <= 1.5'):
            self.assertIn(marker,gate)
