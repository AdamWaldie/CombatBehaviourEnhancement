/*
 * Author: WaldoTheWarfighter
 * Purpose: Consume one actual AA engagement episode into one finite native relocation operation.
 * Locality/authority: Current vehicle/group/AI movement-seat owner through GroupBrainStep only.
 * Native known air contact and original shot/order receipt bound admission. No hidden transform,
 * radar override, firing, free smoke, physics recovery or additional scheduler is introduced.
 * Repeat/JIP: At most one proposal per receipt, original shot+120s expiry, one active group move.
 * Owner/epoch change refuses replay. Completion is observed physically; expiry is not success.
 * Arguments: 0 group GROUP,grpNull; 1 current group state HASHMAP,empty; 2 ordered BOOL,true.
 * 3 current native contacts ARRAY,[], reused for nearby-ground-threat admission.
 * Return: BOOL,true while this exact AA operation owns movement; never firing/interception proof.
 * Current caller: CortexGroupTick after authored stationary/feature-task classification.
 * Example: private _moving=[_group,_state,_ordered] call CBE_fnc_CortexAARelocate;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_ordered",true,[true]],["_contacts",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {false};
private _work=_state getOrDefault ["aaRelocation",createHashMap];
private _vehicle=vehicle leader _group;
if (count _work > 0) then {_vehicle=_work get "vehicle"};
if (count _work == 0 && {isNil {_vehicle getVariable "CBE_AA_LastShot"}}) exitWith {false};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
private _enabled=!_ordered && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)} && {[_group] call CBE_fnc_CortexIsEligible}
    && {[_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleStandoff_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _crewReady={
    _enabled && {!isNull _vehicle} && {local _vehicle} && {alive _vehicle} && {canMove _vehicle}
        && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}
        && {[_vehicle] call CBE_fnc_CortexAirDefenceRole}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
        && {vehicle leader _group == _vehicle} && {count units _group <= 64}
        && {(units _group) findIf {alive _x && {vehicle _x != _vehicle}} < 0}
        && {count (_group getVariable ["CBE_Cortex_CombinedRole",[]]) == 0}
        && {!(_state getOrDefault ["responding",false])} && {!(_state getOrDefault ["assaulting",false])}
        && {combatMode _group in ["YELLOW","RED"]}
        && {[_driver,_operator] findIf {isNull _x || {!local _x} || {isPlayer _x}
            || {group _x != _group} || {vehicle _x != _vehicle} || {!isNull remoteControlled _x}
            || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!(currentCommand _x in ["","MOVE","WAIT"])}} < 0}
};
private _currentThreat={
    private _gunner=gunner _vehicle;
    private _target=assignedTarget _gunner;
    if (isNull _gunner || {isNull _target} || {!alive _target}
        || {(side _group) getFriend (side _target) >= 0.6}) exitWith {false};
    private _knowledge=_gunner targetKnowledge _target;
    private _age=time-(_knowledge select 2);
    (_knowledge select 1) && {_age >= 0} && {_age <= 5}
};
private _finish={
    params ["_success","_reason"];
    private _generation=_work get "generation";
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    if ((_operation getOrDefault ["generation",-2]) == _generation
        && {(_operation getOrDefault ["ownerEpoch",-1]) == (_work get "epoch")}
        && {(_operation getOrDefault ["intent",""]) == "AA_RELOCATE"}) then {
        [_group,_generation,["INCOMPLETE","COMPLETE"] select _success,_reason] call CBE_fnc_OperationRelease;
        if (((_group getVariable ["CBE_Cortex_MovementLease",[]]) param [0,""]) == "AA_RELOCATE"
            && {(_group getVariable ["CBE_OperationGeneration",-2]) == _generation}
            && {(_group getVariable ["CBE_AIPass_Epoch",-1]) == (_work get "epoch")}) then {
            [_group,"AA_RELOCATE",false] call CBE_fnc_CortexOwnershipLease;
            _state deleteAt "movementLease";
        };
    };
    _state deleteAt "aaRelocation";
    _state set ["aaRelocationAfter",serverTime+90];
    _group setVariable ["CBE_AA_RelocationResult",[_generation,_success,_reason,serverTime],true];
    false
};
if (count _work > 0) exitWith {
    if (!(call _crewReady) || {(_work get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {serverTime >= (_work get "until")}) exitWith {[false,"AUTHORITY_OR_EXPIRY"] call _finish};
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    if ((_operation getOrDefault ["generation",-2]) != (_work get "generation")
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_work get "order")}) exitWith {[false,"ORDER_REPLACED"] call _finish};
    if (call _currentThreat) exitWith {[false,"THREAT_RENEWED"] call _finish};
    private _shot=_vehicle getVariable ["CBE_AA_LastShot",[]];
    if ((_vehicle getVariable ["CBE_AA_LastFireAt",-1]) > (_work get "shotAt")) exitWith {[false,"ENGAGEMENT_RENEWED"] call _finish};
    if (_vehicle distance2D (_work get "spot") <= 20
        && {abs (((getPosATL _vehicle) select 2)-((_work get "spot") select 2)) <= 3}) exitWith {[true,"ARRIVED"] call _finish};
    true
};
if (!(call _crewReady) || {!((_state getOrDefault ["phase","CALM"]) in ["CALM","CONTACT"])}
    || {_contacts findIf {(_x select 2) <= 5 && {(_x select 3) < 300} && {!((_x select 0) isKindOf "Air")}} >= 0}
    || {serverTime < (_state getOrDefault ["aaRelocationAfter",-1])}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}) exitWith {false};
if ([_driver,_operator] findIf {currentCommand _x == "MOVE"} >= 0) exitWith {false};
private _shot=_vehicle getVariable ["CBE_AA_LastShot",[]];
if (count _shot != 11 || {(_shot select 0) != clientOwner} || {(_shot select 1) != _group}
    || {(_shot select 2) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
    || {(_shot select 3) <= (_state getOrDefault ["aaRelocationConsumedAt",-1])}
    || {serverTime-(_vehicle getVariable ["CBE_AA_LastFireAt",serverTime]) < 8} || {serverTime-(_shot select 3) >= 120}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_shot select 9)}) exitWith {false};
private _contact=_shot select 10;
if (count _contact != 3 || {serverTime-(_contact select 2) >= 120}) exitWith {false};
private _index=currentWaypoint _group;
if (_index > 0 && {_index < count waypoints _group}) exitWith {false};
// Fresh contacts can defer the same original episode, never extend its expiry.
if (serverTime < (_state getOrDefault ["aaRelocationCheckAt",-1])) exitWith {false};
_state set ["aaRelocationCheckAt",serverTime+5];
if (call _currentThreat) exitWith {false};
private _known=([_group,-1,"AIR"] call CBE_fnc_CortexKnowledge) select 0;
if (_known findIf {(_x select 2) <= 5} >= 0) exitWith {false};
// Consume before geometry: failed terrain planning never retries this receipt.
_state set ["aaRelocationConsumedAt",_shot select 3];
private _origin=getPosATL _vehicle;private _threat=_contact select 1;
private _bearing=_threat getDir _origin;private _candidates=[];
{_candidates pushBack [_origin getPos [150,_bearing+_x]]} forEach [0,-35,35,-70,70];
private _selected=[_origin,_candidates,_threat,[],objNull,"VEHICLE",_vehicle] call CBE_fnc_CortexSelectAvenue;
if (_selected isEqualTo []) exitWith {false};
private _spot=_selected select (count _selected-1);private _started=false;
isNil {
    if (!(call _crewReady) || {(_vehicle getVariable ["CBE_AA_LastShot",[]]) isNotEqualTo _shot}
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_shot select 9)}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}) exitWith {};
    private _until=(_shot select 3)+120;
    if (!([_group,"AA_RELOCATE",true,_until] call CBE_fnc_CortexOwnershipLease)) exitWith {};
    private _operation=[_group,"AA_RELOCATE",_spot,[],[_spot],"MOVING"] call CBE_fnc_OperationStart;
    if (count _operation == 0) exitWith {[_group,"AA_RELOCATE",false] call CBE_fnc_CortexOwnershipLease};
    private _generation=_operation get "generation";
    private _waypoint=[_group,_spot,15,"HOLD",_generation] call CBE_fnc_CortexGroupMove;
    _work=createHashMapFromArray [["vehicle",_vehicle],["generation",_generation],
        ["epoch",_group getVariable ["CBE_AIPass_Epoch",0]],["until",_until],
        ["spot",_spot],["shotAt",_shot select 3],["order",[_group] call CBE_fnc_NativeOrderReceipt]];
    if (isNull (_waypoint param [0,grpNull])) exitWith {[false,"MOVE_REFUSED"] call _finish};
    _state set ["aaRelocation",_work];
    _state set ["movementLease",["AA_RELOCATE",time+((_until-serverTime) max 0)]];
    _started=true;
};
_started
