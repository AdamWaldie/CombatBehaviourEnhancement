/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Remember a group's recently exhausted interior garrison posts for bounded replanning.
 * Locality/authority: Current group owner only; trusted internal call or server-dispatched order.
 * This is advisory selection data, never movement, arrival or universal inaccessibility proof.
 * Repeat/JIP: At most eight entries, each with its original90-second server deadline. Duplicate
 * failures do not renew it. Published data follows group ownership without replaying side effects.
 * Position/direction/up/scale changes, deletion and expiry invalidate an entry on the next read.
 * No scan, timer, worker, native command or assignment mutation is installed. Invalid cache rows
 * are ignored. Explicit initial teleport/in-place placement does not consult this walking policy.
 * Arguments: group GROUP,grpNull; exhausted assignment ARRAY,[] (empty reads without mutation).
 * A record needs the current interior [ATL position,watch bearing,building,admission transform].
 * Return: ARRAY of currently quarantined four-field assignment signatures, at most eight.
 * Current callers: CortexGarrison, CortexGarrisonApplyLocal and CortexGarrisonRefill.
 * Example: private _failed=[group soldier1] call CBE_fnc_CortexGarrisonFailedPosts;
 */
params [["_group",grpNull,[grpNull]],["_assignment",[],[[]]]];
if (isNull _group || {!local _group}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {[]};
private _validSignature={
    params ["_signature"];
    if (!(_signature isEqualType []) || {count _signature != 4}) exitWith {false};
    _signature params ["_point","_bearing","_building","_transform"];
    _point isEqualType [] && {count _point == 3}
        && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_bearing isEqualType 0} && {finite _bearing}
        && {_building isEqualType objNull} && {!isNull _building} && {alive _building}
        && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building,getObjectScale _building]}
};
private _saved=_group getVariable ["CBE_Cortex_GarrisonFailedPosts",[]];
if !(_saved isEqualType []) then {_saved=[]};
private _live=(_saved select [0,8]) select {
    _x isEqualType [] && {count _x == 3}
        && {(_x select 2) isEqualType 0} && {finite (_x select 2)} && {serverTime < (_x select 2)}
        && {(_x select 1) isEqualType 0} && {finite (_x select 1)} && {(_x select 1) > 0}
        && {[_x select 0] call _validSignature}
        && {(_x select 1) == getObjectScale ((_x select 0) select 2)}
};
if (_assignment isNotEqualTo [] && {count _assignment >= 4}
    && {(_assignment param [4,"INTERIOR"]) == "INTERIOR"}) then {
    private _signature=_assignment select [0,4];
    if ([_signature] call _validSignature
        && {_live findIf {(_x select 0) isEqualTo _signature} < 0}) then {
        private _scale=getObjectScale (_signature select 2);
        if (_scale isEqualType 0 && {finite _scale} && {_scale > 0}) then {
            private _copy=[+(_signature select 0),_signature select 1,_signature select 2,
                (_signature select 3) apply {+_x}];
            if (count _live >= 8) then {_live deleteAt 0};
            _live pushBack [_copy,_scale,serverTime+90];
            _group setVariable ["CBE_Cortex_GarrisonFailedPosts",_live,true];
        };
    };
};
_live apply {+(_x select 0)}
