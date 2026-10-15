/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe recognised gate/barrier geometry in the forward body corridor and derive
 * a stationary-obstacle approach cap. A fully open animation is never a passability receipt.
 * Locality/authority: Read-only geometry on the local vehicle owner. The ordinary driving or
 * Server authority may independently resample a remote vehicle without issuing movement.
 * The convoy executor retains the sole speed writer and rechecks its existing movement authority.
 * Repeat/JIP: No handlers, mutation, leases or retained clearance. Live object transforms and
 * collision geometry are sampled each call, including damaged or Zeus-moved gates.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested cap m/s <NUMBER, 20>, clamped 0..35;
 * 2 authoritative server recheck <BOOL, false> permits read-only remote-vehicle geometry on server.
 * Return Value: ARRAY [cap m/s NUMBER, limiting gate OBJECT, hull gap m NUMBER,
 * sampledAt NUMBER, ray count NUMBER]. No hit means no recognised gate constraint, not a clear path.
 * Up to nine body-edge GEOM rays inspect at most four hits each, over a mass-adjusted nominal stopping
 * horizon capped at 600 m. Terrain and unrecognised objects remain native navigation concerns.
 * Recognition is limited to gate/barrier model or class names (including common legacy names);
 * unknown conventions, opening, locks, shared passage ownership and closure are not implemented here.
 * Four-second observation reaction and nominal 1.6..4 m/s^2 braking are provisional safety policy,
 * not measured vehicle braking guarantees. Moving gates and curved approaches need physical QA.
 * Current callers: DrivingAssistStart and ConvoyTick under their existing feature gates.
 * Example: private _gate = [truck1,15] call WAIT_fnc_DrivingGateCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_serverCheck",false,[true]]];
if (!finite _requested) then {_requested=0};
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle && {!(_serverCheck && {isServer})}} || {!alive _vehicle}) exitWith {[_requested,objNull,-1,time,0]};
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _front=(_high select 1)+0.2;
private _left=(_low select 0)-0.2;private _right=(_high select 0)+0.2;
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _velocity=((velocity _vehicle) vectorDotProduct (vectorDir _vehicle)) max 0;
private _speed=_velocity max _requested;
private _horizon=((_speed*_reaction)+((_speed*_speed)/(2*_deceleration))+6) max 25 min 600;
private _nearest=1e9;private _gate=objNull;private _rays=0;
private _bottom=(_low select 2)+0.45;
private _top=((_high select 2)-0.2) max _bottom;
private _heights=[_bottom,(_bottom+_top)*0.5,_top];
_heights=_heights arrayIntersect _heights;
{
    private _height=_x;
    {
        private _from=_vehicle modelToWorldWorld [_x,_front,_height];
        private _to=_vehicle modelToWorldWorld [_x,_front+_horizon,_height];
        _rays=_rays+1;
        private _hits=lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,4,"GEOM","NONE"];
        {
            private _object=_x select 2;
            if (isNull _object) then {_object=_x select 3};
            if (!isNull _object && {_object != _vehicle}) then {
                private _name=toLowerANSI ((typeOf _object)+" "+((getModelInfo _object) param [0,""]));
                if (["gate","barrier","zavora","vrata","branka"] findIf {_name find _x >= 0} >= 0) then {
                    private _gap=_from vectorDistance (_x select 0);
                    if (_gap < _nearest) then {_nearest=_gap;_gate=_object};
                };
            };
        } forEach _hits;
    } forEach [_left,(_left+_right)*0.5,_right];
} forEach _heights;
if (isNull _gate) exitWith {[_requested,objNull,-1,time,_rays]};
private _room=(_nearest-6) max 0;
private _reactionSpeed=_deceleration*_reaction;
private _allowed=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0;
[_requested min _allowed,_gate,_nearest,time,_rays]
