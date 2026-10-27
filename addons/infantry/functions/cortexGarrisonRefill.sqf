/*
 * Author: WaldoTheWarfighter
 * Purpose: Refills one vacant interior garrison post after the arrival job has settled.
 * Locality/authority: current group owner only, through the existing group scheduler. Eligibility,
 * actor reservations and native service/movement commands are checked before replacing a slot.
 * Repeat/JIP: one promotion per settled callback. Fresh physical arrival and exit observation are required for both exterior actors.
 * An alternate exit observer must be unreserved, on foot, natively idle/stopped and not remote controlled,
 * with actual heading within 75 degrees of its watch point before fresh arrival/VIEW confirmation.
 * Initial arrival remains independent of facing so its first watch order can still be installed.
 * Living assignments (including unconscious
 * soldiers) reserve their slots. New-owner ApplyLocal resets the pending marker before adoption.
 * Replacement actors walk; instant placement belongs only to initial explicit task admission.
 * Arguments: 0 group <GROUP>, grpNull.
 * Return: BOOL - assignment issued, not physical arrival or occupation success.
 * Current callers: CBE_fnc_CortexGroupTick.
 * Example: [group soldier1] call CBE_fnc_CortexGarrisonRefill;
 */
params [["_group",grpNull,[grpNull]]];
// Internal scheduled executor, not a public network order endpoint.
if (isRemoteExecuted) exitWith {false};
if (isNull _group || {!local _group} || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _order=_group getVariable ["CBE_AIPass_Garrison",[]];
if (_order isEqualTo [] || {(_group getVariable ["CBE_Cortex_GarrisonPending",-1]) != 0}) exitWith {false};
if !(_group getVariable ["CBE_AIPass_GarrisonApplied",false]) exitWith {false};
private _members=units _group;
if (count _members > 64) exitWith {false};
private _living=_members select {alive _x};
private _roster=(_group getVariable ["CBE_Cortex_GarrisonRoster",_members]) select {!isNull _x && {alive _x} && {group _x == _group}};
if (count _living/((_order param [2,1]) max 1) <= (missionNamespace getVariable ["CBE_AIPass_Garrison_BreakFraction",0.5])) exitWith {false};
private _candidates=(_group getVariable ["CBE_Cortex_GarrisonCandidates",[]]) select [0,64];
if (_candidates isEqualTo []) exitWith {false};
// The group scheduler calls this unscheduled. Read each living assignment once for
// this vacancy pass; no snapshot survives the callback or authorizes later commands.
private _occupiedPosts=[];
{
    private _assignment=_x getVariable ["CBE_AIPass_GarrisonPos",[]];
    if (_assignment isNotEqualTo [] && {(_assignment param [4,"INTERIOR"]) == "INTERIOR"}) then {
        _occupiedPosts pushBack [_assignment param [2,objNull],+(_assignment select 0)];
    };
} forEach _living;
private _failedPosts=[_group] call CBE_fnc_CortexGarrisonFailedPosts;
private _vacancy=[];
{
    private _candidate=_x;
    private _building=_candidate param [2,objNull];
    private _transform=_candidate param [3,[]];
    if (!((_candidate select [0,4]) in _failedPosts) && {!isNull _building} && {alive _building}
        && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        && {_occupiedPosts findIf {
            (_x select 0) == _building
                && {(_x select 1) vectorDistance (_candidate select 0) < 1}
        } < 0}) exitWith {_vacancy=+_candidate};
} forEach _candidates;
if (_vacancy isEqualTo []) exitWith {false};
private _eligible=_living select {
    private _actor=_x;
    private _assignment=_actor getVariable ["CBE_AIPass_GarrisonPos",[]];
    private _free=!([_actor] call CBE_fnc_CortexActorMoveReserved);
    // A previously enrolled actor handed to a newer native task is not a new reinforcement.
    // A mission-disabled PATH is not an available walking reinforcement. The exterior
    // branch below separately proves a settled CBE-owned PATH hold before promotion.
    private _spare=_assignment isEqualTo [] && {!(_actor in _roster)}
        && {_actor checkAIFeature "PATH"};
    if ((_assignment param [4,""]) == "EXTERIOR" && {_actor getVariable ["CBE_AIPass_GarrisonDisabledPath",false]}
        && {!(_actor checkAIFeature "PATH")} && {[_actor,_assignment] call CBE_fnc_CortexGarrisonArrived}) then {
        // Never vacate the sole assigned observation post for this building exit.
        _spare=_living findIf {
            _x != _actor && {local _x} && {!isPlayer _x}
                && {isNull remoteControlled _x} && {isNull objectParent _x}
                && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                && {currentCommand _x in ["","STOP"]}
                && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
                && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                && {!([_group,false,_x] call CBE_fnc_CortexExternalTakeover)} && {[_x] call CBE_fnc_CortexCombatEffective}
                && {_x getVariable ["CBE_AIPass_GarrisonDisabledPath",false]} && {!(_x checkAIFeature "PATH")}
                && {private _other=_x getVariable ["CBE_AIPass_GarrisonPos",[]];
                    (_other param [4,""]) == "EXTERIOR"
                        && {(_other param [2,objNull]) == (_assignment param [2,objNull])}
                        && {(_other param [6,[]]) isEqualTo (_assignment param [6,[]])}
                        && {private _watch=_other param [5,[],[[]]];
                            count _watch == 3 && {abs (((getDir _x-(_x getDir _watch)+540) mod 360)-180) <= 75}}
                        && {[_x,_other] call CBE_fnc_CortexGarrisonArrived}}
        } >= 0;
    };
    _spare && {currentCommand _actor in ["","STOP"]} && {local _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull objectParent _actor} && {_actor checkAIFeature "MOVE"} && {_free}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!(_actor getVariable ["CBE_AIPass_GarrisonFailed",false])}
        && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
        && {!(currentCommand _actor in ["MOVE","FOLLOW","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
if (_eligible isEqualTo []) exitWith {false};
_eligible=[_eligible,[],{_x distance2D (_vacancy select 0)},"ASCEND"] call BIS_fnc_sortBy;
private _actor=_eligible select 0;
if (!local _group || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
if ((_actor getVariable ["CBE_AIPass_GarrisonPos",[]]) isNotEqualTo []) then {
    [_group,false,[_actor]] call CBE_fnc_CortexGarrisonRelease;
};
_actor setVariable ["CBE_AIPass_GarrisonPos",_vacancy,true];
_roster pushBackUnique _actor;
_group setVariable ["CBE_Cortex_GarrisonRoster",_roster,true];
// Only a settled job can open this fresh approach window. Existing failed routes remain failed;
// unfinished routes cannot repeatedly renew their deadline through casualty callbacks.
_group setVariable ["CBE_Cortex_GarrisonDeadline",serverTime+90,true];
[_group,[_actor]] call CBE_fnc_CortexGarrisonApplyLocal;
_group setVariable ["CBE_Cortex_GarrisonRefill",[netId _actor,+(_vacancy select 0),serverTime],true];
true
