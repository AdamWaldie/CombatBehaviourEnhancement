/*
 * Author: WaldoTheWarfighter
 * Passenger stop/continuation proof retains the full current native waypoint identity;
 * same-position policy, script, attachment or synchronization edits end old cooperation.
 * Receives approximate onboard crew contact or targetless danger reports, requests an owner-local
 * safe stop and dismounts this squad's cargo only after the vehicle is physically stationary.
 * Locality/authority: passenger group owner; validates current reporting crew ownership.
 * Same-host original cargo is recorded before CBE exit for finite separate-squad support;
 * cross-host exits submit an authenticated original-cargo acknowledgement, not a troop command or contact reveal.
 * Repeat/JIP: reports bridge the 20-second far scheduler tier without becoming durable; stop requests
 * expire with the report and record each passenger once. Danger reports do not disclose a target.
 * Arguments: 0: group <GROUP>, grpNull; 1: state <HASHMAP>, empty.
 * Return: Nothing. Current caller: CBE_fnc_CortexGroupTick after eligibility and order checks.
 * Example: [_group,_state] call CBE_fnc_CortexOnboardContact;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group} || {!([_group] call CBE_fnc_CortexIsEligible)}) exitWith {};
if (!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)
    || {!([_group,"CBE_AIPass_VehicleDismount_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {};
private _vehicles=[];
{if (alive _x && {vehicle _x != _x}) then {_vehicles pushBackUnique vehicle _x}} forEach units _group;
{
    private _vehicle=_x;
    private _report=_vehicle getVariable ["CBE_Cortex_OnboardReport",[]];
    private _dangerReport=_vehicle getVariable ["CBE_Cortex_OnboardDanger",[]];
    // Prefer whichever bounded crew report remains useful for longer. Both payloads carry only
    // approximate geometry; neither grants the passenger group target identity or knowledge.
    if (count _dangerReport == 4 && {count _report != 4 || {(_dangerReport select 3) > (_report select 3)}}) then {
        _report=_dangerReport;
    };
    if (count _report == 4 && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}) then {
        _report params ["_reporter","_owner","_position","_expiry"];
        if (_reporter isEqualType grpNull && {_owner isEqualType 0} && {_position isEqualType []} && {_expiry isEqualType 0}
            && {!isNull _reporter} && {_reporter != _group} && {count _position == 3}
            && {_position findIf {!(_x isEqualType 0)} < 0}
            && {groupOwner _reporter == _owner} && {group effectiveCommander _vehicle == _reporter}
            && {alive effectiveCommander _vehicle} && {side _reporter == side _group}
            && {serverTime < _expiry} && {_expiry <= serverTime+35}
            && {_vehicle distance2D _position < 400}) then {
            private _onboardCargo=(fullCrew [_vehicle,"",false]) select {
                private _unit=_x select 0;
                private _role=_x select 1;
                alive _unit && {group _unit == _group}
                    && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
            };
            // The passenger owner cannot safely stop a vehicle owned by the crew group. Publish a
            // bounded request which CortexVehicles validates and executes on that vehicle owner.
            // This remains useful even while moving, whereas PassengerReady deliberately rejects
            // a moving vehicle and therefore prevents an unsafe exit.
            if (_onboardCargo isNotEqualTo []) then {
                _vehicle setVariable ["CBE_Cortex_DismountStopRequest",[_group,groupOwner _group,serverTime+30],true];
            };
            private _cargo=_onboardCargo apply {_x select 0};
            _cargo=_cargo select {[_x,_vehicle] call CBE_fnc_CortexPassengerReady};
            private _owned=_state getOrDefault ["dismounted",[]];
            {
                private _unit=_x;
                private _newExit=_owned findIf {(_x select 0) == _unit} < 0;
                if (_newExit) then {
                    _owned pushBack [_unit,_vehicle];
                    _group setVariable ["CBE_Cortex_DismountContinuation",[serverTime+60,
                        _group getVariable ["CBE_OperationGeneration",0],+_owned,
                        [_group] call CBE_fnc_NativeOrderReceipt],true];
                };
                _state set ["dismounted",_owned];
                _state set ["onboardContactUntil",serverTime+30];
                // Same-host crew and passenger owners can commit actual-carriage consent
                // synchronously before exit. Remote owners use the authenticated relay below.
                if (_newExit && {local _vehicle} && {local _reporter}) then {
                    [_vehicle,_reporter,"ACK",_unit] call CBE_fnc_CortexMechanisedCargo;
                };
                if (_newExit && {!local _vehicle}) then {
                    [_group,"EXIT",_vehicle,_unit] call CBE_fnc_CortexMechanisedRemote;
                };
                // Preserve the engine's in-progress exit animation/order. A later interrupted
                // command may be retried on the next eligible tick, but healthy exits are not reissued.
                if (toUpperANSI (currentCommand _unit) != "GET OUT"
                    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
                    && {group effectiveCommander _vehicle == _reporter}
                    && {groupOwner _reporter == _owner}
                    && {!([_reporter] call CBE_fnc_CortexExternalTakeover)}) then {
                    [_unit] orderGetIn false;
                    unassignVehicle _unit;
                    doGetOut _unit;
                };
            } forEach _cargo;
        };
    };
} forEach _vehicles;
// Contact and danger reports do not manufacture visual contact. If no native contact followed the exit,
// restore only this calm passenger episode through the normal guarded remount path.
if ("onboardContactUntil" in _state && {serverTime >= (_state get "onboardContactUntil")}
    && {(_state getOrDefault ["phase",""]) == "CALM"}) then {
    _state deleteAt "onboardContactUntil";
    [_group,_state,true,false,"ONBOARD_REPORT_EXPIRED"] call CBE_fnc_CortexRestoreCalm;
};
