/*
 * Author: WaldoTheWarfighter
 * Purpose: Read a land platform's dedicated AA role declaration, otherwise infer native config intent.
 * Live CBE_AirDefenceRole BOOL true/false selects dedicated/ordinary role; unset or NUMBER-1
 * inherits native config. Other values refuse. Declaration is read before the immutable class memo.
 * Existing AA editor categories qualify. A custom category qualifies only when all three native
 * threat weights are finite/nonnegative and the positive air weight strictly exceeds both
 * soft and armour weights. Equal/mixed/default ground profiles do not gain the dedicated role.
 * This is configured role intent, never proof of loaded AA weapons, lock, contact or fire safety.
 * Locality / Authority: Read-only on any machine. Actual observers/executors retain current
 * crew, weapon, task, feature and owner gates; no role result grants commands or adoption.
 * Repeat/JIP: Current published declaration is read on every call; no live declaration is cached.
 * Role changes grant no event replay or immediate native-command quiescence.
 * At most256 immutable class results are memoised per machine. Overflow computes
 * without storing. No object/public state, expiry, native-task cache, worker or handler.
 * Arguments: 0 platform OBJECT,objNull.
 * Return Value: BOOL dedicated air-defence role hint, false for non-land/null/ambiguous config.
 * Current callers: AA observer/allocation/interception/relocation, vehicle gunnery and armour-shot admission.
 * Example: private _airDefence=[vehicle1] call CBE_fnc_CortexAirDefenceRole;
 */
params [["_vehicle",objNull,[objNull]]];
if (isNull _vehicle || {!(_vehicle isKindOf "LandVehicle")}) exitWith {false};
// A mission role declaration selects intent; global CBA and current executor gates still win.
private _declared=_vehicle getVariable ["CBE_AirDefenceRole",-1];
if (_declared isEqualType true) exitWith {_declared};
if !(_declared isEqualTo -1) exitWith {false};
private _class=typeOf _vehicle;
if (isNil "CBE_AirDefenceRoleClasses") then {CBE_AirDefenceRoleClasses=createHashMap};
private _role=CBE_AirDefenceRoleClasses getOrDefault [_class,-1];
if (_role isEqualTo -1) then {
    private _config=configOf _vehicle;
    _role=toLowerANSI getText (_config >> "editorSubcategory") == "edsubcat_aas";
    if (!_role) then {
        private _threat=getArray (_config >> "threat");
        _role=count _threat == 3
            && {_threat findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} < 0}
            && {(_threat select 2) > 0}
            && {(_threat select 2) > (_threat select 0)}
            && {(_threat select 2) > (_threat select 1)};
    };
    if (count CBE_AirDefenceRoleClasses < 256) then {CBE_AirDefenceRoleClasses set [_class,_role]};
};
_role
