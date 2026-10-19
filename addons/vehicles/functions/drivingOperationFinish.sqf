/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires matching ordinary driving work and releases only its tracked speed leases.
 * Failed FSM startup or exhausted executor restart retains a terminal route receipt after exact cleanup, so discovery
 * cannot loop on a failed executor or silently replenish its retry budgets.
 * Locality / Authority: Native cleanup requires the current local group/brain. Exact private
 * observer/consent retirement runs on the original machine even after locality loss; it grants
 * no native command. No ownership transfer or second scheduler.
 * Repeat/JIP: Exact epoch/generation removes the finite pass STOP observer without touching
 * a successor handler. Tracked queue/pass consent and preparation retire only for this
 * exact brain/epoch/generation through authenticated broker release, without cancelling
 * successors or waiting for the old token timer. Current-brain identity gates native cleanup. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 brain <HASHMAP, empty>; 1 reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: CBE drivingOperation FSM, DrivingOperationStart, CortexReleaseGroup
 * and CortexLocality.
 * Example: [_brain,"ZEUS"] call CBE_fnc_DrivingOperationFinish;
 */
params [["_brain",createHashMap,[createHashMap]],["_reason","RELEASED",[""]]];
_brain set ["cancelled",true];_brain set ["finished",true];_brain set ["pending",false];
_brain set ["completed",true];_brain set ["cancelReason",_reason];
private _group=_brain getOrDefault ["group",grpNull];
if (!isNull _group) then {
    private _watch=_group getVariable ["CBE_DrivingPass_CommandWatch",[]];
    if (count _watch == 6 && {(_watch select 2) == (_brain getOrDefault ["ownerEpoch",-1])}
        && {(_watch select 3) == (_brain getOrDefault ["generation",-1])}) then {
        [_group,_watch select 0,createHashMapFromArray [["token",_watch select 1],
            ["epoch",_watch select 2],["generation",_watch select 3]],true]
            call CBE_fnc_DrivingPassCommandWatch;
    };
};
// Consent can outlive this brain's command authority. Retire only its exact machine-local
// receipt before the current-brain guard; successor generations are checked by the helper.
if (!isNull _group) then {
    {
        [_x,_group,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["generation",-1]]
            call CBE_fnc_DrivingQueueAgreementRelease;
        ["CANCEL",_group,_x,_brain] call CBE_fnc_DrivingPassAdmission;
        private _retireEpoch=_brain getOrDefault ["ownerEpoch",-1];
        private _retireGeneration=_brain getOrDefault ["generation",-1];
        if (_retireEpoch >= 0 && {_retireGeneration >= 0}) then {
            // Context generation binds active, pending and passive peer consent.
            // No active pass-work record is required to withdraw participation.
            [_x,_group,"",_retireEpoch,_retireGeneration] call CBE_fnc_DrivingPassAgreementRelease;
        };
    } forEach (_group getVariable ["CBE_DrivingAssist_Vehicles",[]]);
};
if (isNull _group || {!local _group}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {};
[_group,_brain,true] call CBE_fnc_DrivingCrewStep;
{[_x,_group] call CBE_fnc_DrivingAssistRelease} forEach (_group getVariable ["CBE_DrivingAssist_Vehicles",[]]);
_group setVariable ["CBE_DrivingAssist_Vehicles",nil];
_group setVariable ["CBE_Driving_FSM",nil];
_group setVariable ["CBE_Driving_State",["HANDBACK",_brain get "generation",serverTime,_reason,clientOwner,_brain get "ownerEpoch"],true];
// Keep exhausted/failed-start routes terminal. A new order may start a new operation.
if !(_reason in ["EXHAUSTED","FSM_START_FAILED","FSM_RESTART_EXHAUSTED"]) then {_group setVariable ["CBE_Driving_Brain",nil]};
