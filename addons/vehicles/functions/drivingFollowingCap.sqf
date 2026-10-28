/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes vehicle hulls occupying the chosen travel lane and derives a continuous speed cap.
 * Explicit reverse observation uses the existing2m rear end buffer instead of the forward6m
 * stand-off and rotates the metre frame to the rear bumper; all crossing courses
 * yield and no convoy predecessor spacing is delegated. It issues no direction command.
 * Aligned moving predecessors retain measured forward speed. Other intersecting hulls are treated
 * as occupied space without assuming that crossing or oncoming traffic will yield or move away.
 * Dense unscheduled samples project at most256 hulls. Finite separated-height hulls and
 * non-occupying slow/parallel courses that cannot affect either existing constraint branch
 * are pruned before at most64 motion predictions. More than64 retained candidates still refuse. Scheduled
 * direct calls retain the original64-candidate refusal; no cross-suspension pruning cache.
 * Moving crossing traffic on the right also constrains approach when projected hull occupancy
 * windows overlap within six seconds. Crossing actors from either side inside nominal stopping
 * room also constrain imminent collision; priority never assumes an unacknowledged peer yields.
 * Current measured velocity defines the other course;
 * desired/actual forward speed defines our approach. Current vertical overlap is required.
 * Time-window yielding never clears an occupied hull or expires into permission to drive through it.
 * Land, aircraft and boat hulls share the same lane/height and crossing observation.
 * This covers roadway aircraft, grounded boats and their wrecks without a world-wide dead scan.
 * Height-separated traffic retains the existing full-hull vertical test and dense-scene refusal.
 * Unknown heading or nonfinite own/peer hull projection returns a zero cap and the same
 * unavailable-observation sentinel as a budget refusal. No unknown hull is treated as clear.
 * Empty live vehicles and destroyed vehicle entities at any heading remain obstacles;
 * destruction alone never removes their hull from this observation. No bypass route is planned.
 * A mass-adjusted closing-speed envelope adds provisional braking and cruise-sampling headroom;
 * Oncoming/reversing lane hulls retain their measured approach speed through reaction and
 * own braking time; treating that component as stationary would overstate available room.
 * This only lowers the existing cap and cannot make an uncooperative peer stop or yield.
 * Neither nominal deceleration nor scheduler response is physically guaranteed by this policy.
 * Locality/authority: read-only on the current vehicle owner. The driving operation owns all
 * speed commands and rechecks its driver, route and movement lease before applying this result.
 * Repeat/JIP: no handlers or cached clearance. Each sample uses actual velocity and current hull
 * full-hull bounds; results must not be replayed after movement, route replacement or locality change.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 requested cap m/s <NUMBER>, 20 (0..35);
 * 2 registered predecessor <OBJECT>, objNull. Only its alive, aligned, non-reversing
 * longitudinal spacing is delegated to the convoy; crossing and close hull occupancy remain checked.
 * 3 optional queue proof HASHMAP empty: only a current granted QUEUE FOLLOW delegates
 * its frozen held hulls to the existing path geometry; all other vehicles remain observed.
 * 4 travel direction NUMBER 1: +1 forward or -1 reverse; other values refuse with zero cap.
 * Return: ARRAY [cap m/s NUMBER, limiting vehicle OBJECT, hull gap m NUMBER,
 * sampledAt NUMBER, candidate count NUMBER, nearby conflict BOOL]. The sixth field requests
 * earlier observation only for closing/crossing conflicts; stable same-speed following
 * does not request faster sampling. It grants no speed, clearance or right of way. Gap is bumper room or predicted crossing stop room. Dense sets return zero and the vehicle itself as
 * a congestion sentinel when discovery or retained-prediction budgets exceed their bounds.
 * Four world transforms per hull represent all eight corners in one horizontal world-metre
 * frame, with a0.05m outward pad per other-hull boundary. The observing hull is projected once
 * in the same frame. Pitch/roll and object scale cannot turn metre gaps into model units or
 * tilt the vertical-overlap axis. Scale support remains subject to engine simulation limits.
 * Discovery includes six seconds of own travel plus a nominal 35 m/s opposing/crossing
 * approach and 20 m hull margin, capped at 500 m. An over-budget envelope refuses before
 * querying. Faster approaching traffic and unusually large modded hulls remain limitations.
 * This observation horizon does not establish a physical stopping-distance guarantee.
 * Current callers: DrivingAssistStart and ConvoyTick through their finite operation schedulers.
 * Example: private _traffic = [truck1,20] call CBE_fnc_DrivingFollowingCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_predecessor",objNull,[objNull]],["_queueProof",createHashMap,[createHashMap]],["_travelDirection",1,[0]]];
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[_requested,objNull,-1,time,0,false]};
if (!(_travelDirection in [-1,1])) exitWith {[0,_vehicle,-1,time,0,true]};
private _box=boundingBoxReal _vehicle;
private _modelLow=_box select 0;private _modelHigh=_box select 1;
private _forward=vectorDir _vehicle;_forward set [2,0];
if (_forward findIf {!finite _x} >= 0 || {vectorMagnitude _forward < 0.1}) exitWith {[0,_vehicle,-1,time,0,true]};
_forward=(vectorNormalized _forward) vectorMultiply _travelDirection;
private _right=[_forward select 1,-(_forward select 0),0];
private _ownCentre=_vehicle modelToWorldWorld ((_modelLow vectorAdd _modelHigh) vectorMultiply 0.5);
// Both hulls use horizontal forward/right and absolute vertical axes. Their extents, gaps,
// crossing windows and measured velocity therefore share metres even on pitched/rolled hulls.
private _projectTrafficHull={
    params ["_hull","_hullLow","_hullHigh"];
    private _corner=(_hull modelToWorldWorld _hullLow) vectorDiff _ownCentre;
    private _origin=[_corner vectorDotProduct _right,_corner vectorDotProduct _forward,_corner select 2];
    private _projectedLow=+_origin;private _projectedHigh=+_origin;
    {
        private _edge=(_hull modelToWorldWorld _x) vectorDiff _ownCentre;
        _edge=[_edge vectorDotProduct _right,_edge vectorDotProduct _forward,_edge select 2];
        _edge=_edge vectorDiff _origin;
        for "_axis" from 0 to 2 do {
            private _component=_edge select _axis;
            _projectedLow set [_axis,(_projectedLow select _axis)+(_component min 0)];
            _projectedHigh set [_axis,(_projectedHigh select _axis)+(_component max 0)];
        };
    } forEach [[_hullHigh select 0,_hullLow select 1,_hullLow select 2],
        [_hullLow select 0,_hullHigh select 1,_hullLow select 2],
        [_hullLow select 0,_hullLow select 1,_hullHigh select 2]];
    [_projectedLow,_projectedHigh]
};
private _ownHull=[_vehicle,_modelLow,_modelHigh] call _projectTrafficHull;
private _low=_ownHull select 0;private _high=_ownHull select 1;
private _ownProjectionFinite=(_low+_high) findIf {!finite _x} < 0;
if (!_ownProjectionFinite) exitWith {[0,_vehicle,-1,time,0,true]};
private _front=_high select 1;
private _halfWidth=((_high select 0)-(_low select 0))*0.5;
private _halfLength=((_high select 1)-(_low select 1))*0.5;
private _plannedSpeed=0;
private _ownForward=((velocity _vehicle) vectorDotProduct _forward) max 0;
// Heavy vehicles get a lower nominal deceleration. Account for the ordinary four-second
// cruise sampling interval even though a constrained phase requests work more frequently.
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
_plannedSpeed=(_ownForward max _requested) max 0.5;
// Relative approach matters even while we are nearly stopped: a crossing vehicle
// can enter our six-second conflict window from well outside our own travel radius.
// Use the same finite prediction horizon plus a nominal 35 m/s approaching course.
// The 20 m margin is provisional hull/discovery headroom, not arbitrary mod-size coverage.
private _horizon=6;
private _approachAllowance=35*_horizon;
private _radius=(_ownForward max _requested)*_horizon+_approachAllowance+20+(abs _front);
if (!finite _radius || {_radius > 500}) exitWith {[0,_vehicle,-1,time,0,true]};
// Arma 2.18 area syntax explicitly includes dead vehicle entities. The default
// radius syntax omits them; removing only the alive predicate would not fix discovery.
// Aircraft/boat hulls can obstruct or cross a roadway too. Reuse this one bounded
// observation and its vertical-occupancy checks; do not add a separate wreck/world scan.
private _area=[getPosATL _vehicle,_radius,_radius,0,false,_radius];
private _candidates=_area nearEntities [["LandVehicle","Air","Ship"],false,false,false];
private _denseTraffic=count _candidates > 64;
// Dense scenes retain exact hull projection rather than guessing by centre distance.
// Scheduled direct callers keep the original refusal: the pruning snapshot is owner
// callback work, not a cache across a possible suspension. Native query cost is unchanged.
if (count _candidates > 256 || {_denseTraffic && {canSuspend}}) exitWith {[0,_vehicle,-1,time,count _candidates,true]};
private _evaluated=0;private _predictionBudgetExceeded=false;
// Only a current granted QUEUE FOLLOW path can delegate its frozen held hulls
// to the shared path geometry. Other traffic and the dense-candidate budget remain.
private _pathHulls=[];
if (_travelDirection == 1 && {count _queueProof > 0}) then {
    private _queueVehicles=_queueProof getOrDefault ["vehicles",[]];
    private _work=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
    if ((_queueVehicles param [0,objNull]) == _vehicle
        && {_queueProof getOrDefault ["crossingGranted",false]}
        && {(_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isEqualTo _queueProof}
        && {(_work getOrDefault ["controller",[]]) isEqualTo ["QUEUE",-1]}
        && {(_work getOrDefault ["phase",""]) == "FOLLOW"}
        && {(_work getOrDefault ["queueCrossingBinding",[]]) isEqualTo (_queueProof getOrDefault ["crossingBinding",[]])}
        && {[_queueProof,true] call CBE_fnc_DrivingQueueReverseCurrent}) then {_pathHulls=_queueVehicles select [1]};
};
private _standOff=[6,2] select (_travelDirection < 0);
private _cap=_requested;private _limiting=objNull;private _gap=-1;private _nearConflict=false;
{
    if (_predictionBudgetExceeded) exitWith {};
    private _other=_x;
    if (_other != _vehicle && {!isNull _other} && {!(_other in _pathHulls)}) then {
        // Heading selects only the following-speed allowance, never obstacle admission.
        // An angled parked hull or a reversing/oncoming vehicle still occupies this lane.
        private _following=((vectorDir _other) vectorDotProduct _forward) > 0.7
            && {((velocity _other) vectorDotProduct _forward) >= -0.5};
        // A registered predecessor is not permission to omit its physical hull.
        // Convoy centre-distance spacing applies only while the pair remains aligned.
        private _spacingOwned=_travelDirection == 1 && {_other == _predecessor} && {alive _other}
            && {_following} && {((vectorDir _other) vectorDotProduct _forward) >= cos 25};
        if (_other == _predecessor && {!_spacingOwned}) then {_following=false};
        private _otherForward=if (_following) then {
            ((velocity _other) vectorDotProduct _forward) max 0
        } else {0};
        private _otherBox=boundingBoxReal _other;
        private _otherLow=_otherBox select 0;private _otherHigh=_otherBox select 1;
        // One affine corner and three edges represent every hull corner in the same
        // horizontal world frame as our own hull, crossing course and braking distances.
        private _otherHull=[_other,_otherLow,_otherHigh] call _projectTrafficHull;
        private _projectedLow=_otherHull select 0;private _projectedHigh=_otherHull select 1;
        // Unknown vertical bounds must not disappear through false overlap comparisons.
        // Stop the existing bounded observation; do not return a clear lane or add a retry.
        if ((_projectedLow+_projectedHigh) findIf {!finite _x} >= 0) exitWith {_predictionBudgetExceeded=true};
        // A small outward pad avoids narrowing the safety envelope through subtraction rounding.
        private _minX=(_projectedLow select 0)-0.05;private _maxX=(_projectedHigh select 0)+0.05;
        private _minY=(_projectedLow select 1)-0.05;private _maxY=(_projectedHigh select 1)+0.05;
        private _minZ=(_projectedLow select 2)-0.05;private _maxZ=(_projectedHigh select 2)+0.05;
        // A long sideways hull can intrude past our front even when its centre is behind it.
        private _ahead=_maxY > _front-0.25;
        private _sameLane=_maxX >= (_low select 0)-0.25 && {_minX <= (_high select 0)+0.25};
        private _sameHeight=_maxZ >= (_low select 2)-0.25 && {_minZ <= (_high select 2)+0.25};
        // Project crossing occupancy on measured courses rather than stopping merely for
        // closeness. Normal approach yields to the right; either side can require emergency
        // braking inside stopping room. No peer has acknowledged that it will give way.
        // Current lane occupancy below remains independent of this prediction.
        private _otherVelocity=velocity _other;_otherVelocity set [2,0];
        private _otherSpeed=vectorMagnitude _otherVelocity;
        // Derive the same crossing denominator before spending a prediction slot.
        // Parallel courses below the existing cutoff cannot enter that branch; current
        // occupied-lane hulls remain independent. Unknown data is never pruned.
        private _course=[];private _denominator=0;
        if (_sameHeight && {_otherSpeed > 0.8}) then {
            _course=vectorNormalized _otherVelocity;
            _denominator=(_forward select 0)*(_course select 1)-(_forward select 1)*(_course select 0);
        };
        if (_denseTraffic && {finite _otherSpeed} && {_ownProjectionFinite}
            && {[_minX,_maxX,_minY,_maxY,_minZ,_maxZ] findIf {!finite _x} < 0}
            && {!_sameHeight || {
                !(_ahead && {_sameLane}) && {_otherSpeed <= 0.8
                    || {finite _denominator && {abs _denominator <= 0.2}}}
            }}) then {continue};
        _evaluated=_evaluated+1;
        if (_evaluated > 64) exitWith {_predictionBudgetExceeded=true};
        private _otherCentre=_other modelToWorldWorld ((_otherLow vectorAdd _otherHigh) vectorMultiply 0.5);
        private _relative=_otherCentre vectorDiff _ownCentre;_relative set [2,0];
        private _fromRight=_travelDirection < 0 || {_relative vectorDotProduct _right > 0.25};
        if (_sameHeight && {_otherSpeed > 0.8}) then {
            if (abs _denominator > 0.2) then {
                private _alongOwn=((_relative select 0)*(_course select 1)-(_relative select 1)*(_course select 0))/_denominator;
                private _alongOther=((_relative select 0)*(_forward select 1)-(_relative select 1)*(_forward select 0))/_denominator;
                private _otherHalfLength=((_maxX-_minX)*(abs (_course vectorDotProduct _right))+(_maxY-_minY)*(abs (_course vectorDotProduct _forward)))*0.5;
                private _ownWindow=_halfLength+(_maxY-_minY)*0.5+2.5;
                private _alignment=abs (_forward vectorDotProduct _course);
                private _otherWindow=_otherHalfLength+_halfLength*_alignment+_halfWidth*(abs _denominator)+2.5;
                private _ownIn=(_alongOwn-_ownWindow)/_plannedSpeed;private _ownOut=(_alongOwn+_ownWindow)/_plannedSpeed;
                private _otherIn=(_alongOther-_otherWindow)/_otherSpeed;private _otherOut=(_alongOther+_otherWindow)/_otherSpeed;
                if (_ownIn < _horizon && {_otherIn < _horizon} && {_ownOut > 0} && {_otherOut > 0}
                    && {_ownIn < _otherOut+1} && {_otherIn < _ownOut+1}) then {
                    private _room=(_alongOwn-_ownWindow) max 0;
                    private _arrivalCap=_room/((_otherOut+1) max 0.5);
                    private _reactionSpeed=_deceleration*_reaction;
                    private _brakingCap=(sqrt ((_reactionSpeed^2)+2*_deceleration*_room)-_reactionSpeed) max 0;
                    private _allowed=_arrivalCap min _brakingCap;
                    private _stoppingRoom=_ownForward*_reaction+(_ownForward^2)/(2*_deceleration);
                    if (_fromRight || {_room <= _stoppingRoom}) then {_nearConflict=true};
                    if (_room <= _stoppingRoom) then {_allowed=0};
                    if ((_fromRight || {_room <= _stoppingRoom}) && {_allowed < _cap}) then {
                        _cap=_allowed;_limiting=_other;_gap=_room
                    };
                };
            };
        };
        if (_ahead && {_sameLane} && {_sameHeight}) then {
            private _hullGap=(_minY-_front) max 0;
            // Anticipation changes cadence only, including a peer not yet lowering our cap.
            // Same-lane and same-height hull tests above keep adjacent/stacked traffic out.
            private _watchRoom=40 max (_ownForward*_reaction+(_ownForward^2)/(2*_deceleration));
            if (_hullGap <= _watchRoom && {!_following || {_ownForward-_otherForward > 0.5}}) then {_nearConflict=true};
            if (_spacingOwned) then {
                // Normal convoy gaps keep their own pacing model. Even an aligned
                // predecessor cannot exempt contact-range body overlap from braking.
                if (_hullGap < 2 && {_cap > 0}) then {_cap=0;_limiting=_other;_gap=_hullGap};
            } else {
            // Direction-specific stand-off plus 1.8 seconds of predecessor travel. Continuous correction
            // avoids binary distance-band starts/stops. Closing-distance reaction only lowers it.
            private _allowed=(_otherForward+((_hullGap-_standOff-(_otherForward*1.8))/3)) max 0;
            // Solve closing distance = reaction*relative speed + relative speed^2/(2*a).
            // This limits approach toward the currently measured predecessor speed; it does
            // not assume that a predecessor's future braking or native steering is known.
            private _room=(_hullGap-_standOff) max 0;
            private _reactionSpeed=_deceleration*_reaction;
            private _closingAllowance=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0;
            _allowed=_allowed min (_otherForward+_closingAllowance);
            // A hull approaching along our lane keeps closing while we react AND brake.
            // v*T + v^2/(2*a) + u*(T+v/a) <= room, where u is its current approach.
            // This is a provisional own-speed bound, not consent or a collision guarantee.
            private _approachSpeed=(-((velocity _other) vectorDotProduct _forward)) max 0;
            if (_approachSpeed > 0.5) then {
                private _remainingRoom=(_room-_approachSpeed*_reaction) max 0;
                private _approachCoefficient=_approachSpeed+_reactionSpeed;
                private _approachAllowance=(sqrt ((_approachCoefficient^2)+2*_deceleration*_remainingRoom)-_approachCoefficient) max 0;
                private _actualStoppingRoom=_ownForward*_reaction+(_ownForward^2)/(2*_deceleration)
                    +_approachSpeed*(_reaction+_ownForward/_deceleration);
                if (_room <= _actualStoppingRoom) then {_approachAllowance=0};
                _allowed=_allowed min _approachAllowance;
            };
            private _closing=(_ownForward-_otherForward) max 0;
            if (_closing > 0.5 && {_hullGap < 2+(_closing*0.5)}) then {_allowed=0};
            if (_allowed < _cap) then {_cap=_allowed;_limiting=_other;_gap=_hullGap};
            };
        };
    };
} forEach _candidates;
if (_predictionBudgetExceeded) exitWith {[0,_vehicle,-1,time,count _candidates,true]};
[_cap,_limiting,_gap,time,count _candidates,_nearConflict]
