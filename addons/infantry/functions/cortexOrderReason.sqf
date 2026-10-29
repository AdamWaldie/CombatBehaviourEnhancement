/*
 * Author: WaldoTheWarfighter
 * Explains why an explicit Cortex order cannot run, before touching the group's current orders.
 * Locality/authority: read-only anywhere; the current owner repeats this check before execution.
 * Repeat/JIP: no handlers, state changes or replay. Empty string means no known blocker.
 * Arguments: 0: group <GROUP>, grpNull; 1: order <STRING>, empty; 2: building <OBJECT>, objNull.
 * Return: STRING describing the blocker, or empty when the order may proceed.
 * Current caller: CortexOrderLocal before changing task control.
 * Airborne preflight observes the same actual cargo/FFV riders as the existing executor,
 * without requiring the group leader aboard or changing seating, orders or feature settings.
 * Example: [_group,"DEFEND"] call CBE_fnc_CortexOrderReason;
 */
params [["_group",grpNull,[grpNull]],["_order","",[""]],["_building",objNull,[objNull]]];
if (isNull _group) exitWith {"Select a squad first."};
private _alive = units _group select {alive _x};
if (_alive isEqualTo []) exitWith {"The selected squad has no living members."};
if (units _group findIf {isPlayer _x} >= 0) exitWith {"Player squads cannot be given Cortex orders."};
if (_order in ["RELEASE","EXCLUDE","RETURN","VEHICLE_POINT_RELEASE"]) exitWith {""};
if !(missionNamespace getVariable ["CBE_AIPass_Enable",false]) exitWith {"Cortex behaviours are disabled. Enable them in CBA addon settings first."};
if (local _group && {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}) exitWith {"Cortex is not ready on this squad's owner. Wait for settings to reach that machine and retry."};
if !([_group,true] call CBE_fnc_CortexIsEligible) exitWith {"This squad is excluded, remote-controlled, outside the configured AI filters, or controlled by another feature. Release that control first."};
if (_order == "AIRBORNE") exitWith {
    // Match the executor's first living local airframe, not the leader's possibly ground position.
    // Non-owner readers can inspect availability; only the current owner may execute a drop.
    private _riding=_alive select {(!local _group || {local _x})
        && {(vehicle _x) isKindOf "Air"} && {!((vehicle _x) isKindOf "ParachuteBase")}};
    if (_riding isEqualTo []) exitWith {"No members of this squad are riding an aircraft."};
    private _air=vehicle (_riding select 0);
    private _pilot=driver _air;
    if (!([_pilot] call CBE_fnc_CortexCombatEffective) || {isPlayer _pilot}
        || {isPlayer effectiveCommander _air}) exitWith {"The aircraft needs capable AI flight crew."};
    if ((getPos _air select 2) < (missionNamespace getVariable ["CBE_AIPass_Airborne_MinAltitude",120])
        || {surfaceIsWater getPos _air}) exitWith {"The aircraft must be above the configured jump altitude and over land."};
    private _passengers=((fullCrew [_air,"cargo"])
        +((fullCrew [_air,"turret"]) select {_x select 4})) apply {_x select 0};
    if (_riding findIf {vehicle _x == _air && {_x in _passengers}
        && {[_x] call CBE_fnc_CortexCombatEffective}} < 0) exitWith {"No capable cargo or passenger-turret soldiers in this squad are ready to jump."};
    ""
};
if (_order == "VEHICLE_POINT") exitWith {""};
private _foot = _alive select {vehicle _x == _x && {[_x] call CBE_fnc_CortexCombatEffective}};
if (_foot isEqualTo []) exitWith {"The squad needs capable infantry on foot. Dismount its passengers before issuing this order."};
if (_order == "CLEAR" && {isNull _building || {!(_building isKindOf "House")} || {(_building buildingPos -1) isEqualTo []}}) exitWith {"Place Clear Building on a building with usable interior positions."};
if (_order == "CLEAR" && {count _foot < 2}) exitWith {"Clearing needs at least two capable soldiers on foot: a leader and a clearing soldier."};
""
