/*
 * Author: WaldoTheWarfighter
 * Purpose: Commit one planned patrol leg through the existing common native movement owner.
 * Locality/authority: Internal group owner only, exact PATROL operation generation/epoch/route.
 * The native group waypoint affects every living member, so protected/mounted/unavailable
 * members refuse. No authored waypoint is removed/rewritten; actor flags/poses/skills,
 * group membership and targets stay with their existing owners.
 * Repeat/JIP: Existing CortexGroupMove handles idempotence and exact waypoint cleanup through
 * OperationCancel/OperationRelease. No new native writer, record, loop, worker or replay.
 * New leg issues stop after the original operation's local startedAt+300s; this grants no
 * deadline renewal, native cancellation or physical arrival. A task watchdog is still required.
 * Arguments: 0 group GROUP,grpNull; 1 operation generation NUMBER,-1; 2 route index NUMBER,0.
 * Return: Native waypoint [group,index], or[grpNull,-1]. Task start/progress/watchdog/locality
 * continuation and modules remain pending; this internal leg primitive is not a full patrol.
 * Current callers: patrol task integration pending; common-operation primitive only.
 * Example: [_group,_operation get "generation",0] call CBE_fnc_PatrolRouteCommit;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_index",0,[0]]];
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {!finite _generation} || {_generation < 0}
    || {!finite _index} || {_index != floor _index} || {_index < 0}) exitWith {[grpNull,-1]};
private _committed=[grpNull,-1];
isNil {
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
    private _started=_operation getOrDefault ["startedAt",-1];
    private _route=_operation getOrDefault ["route",[]];
    private _members=units _group;
    if ((_operation getOrDefault ["intent",""]) != "PATROL"
        || {(_operation getOrDefault ["generation",-2]) != _generation}
        || {(_operation getOrDefault ["ownerEpoch",-2]) != _epoch}
        || {(_operation getOrDefault ["phase",""]) in ["CANCELLED","COMPLETE"]}
        || {!(_started isEqualType 0)} || {!finite _started} || {_started < 0}
        || {time < _started} || {time >= _started+300}
        || {!(_route isEqualType [])} || {count _route < 3} || {count _route > 8}
        || {_index >= count _route}
        || {_route findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
        || {count _members == 0} || {count _members > 64}
        || {_members findIf {alive _x && {(!local _x) || {!isNull objectParent _x}
            || {!simulationEnabled _x} || {isObjectHidden _x} || {isPlayer _x}
            || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x == "STOP"}}} >= 0}) exitWith {};
    // This existing writer repeats locality/operation/native-task and waypoint-policy proof
    // at its actual command boundary. Its exact generation cleanup remains the sole owner.
    _committed=[_group,+(_route select _index),5,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
};
_committed
