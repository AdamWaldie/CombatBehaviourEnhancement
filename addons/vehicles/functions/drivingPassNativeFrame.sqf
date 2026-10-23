/*
 * Author: WaldoTheWarfighter
 * Purpose: Read exact native command proof for one consenting vehicle on its actual owner.
 * Locality/authority: Local vehicle, crew group, driver and commander only; remote returns [].
 * Repeat/JIP: Stateless, no commands, handlers, publication or replay. Re-read at consuming boundary.
 * Arguments: 0 vehicle <OBJECT, objNull>.
 * Return: ARRAY [driver,operator,driver command,driver destination,operator command,operator destination], or[].
 * Current callers: Passing plan/preparation/geometry/traffic, consent owner, begin, step and ordinary driving.
 * Example: private _frame=[truck1] call CBE_fnc_DrivingPassNativeFrame;
 */
params [["_vehicle",objNull,[objNull]]];
if (isNull _vehicle || {!local _vehicle}) exitWith {[]};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=_driver};
if (isNull _driver || {isNull _operator} || {!local _driver} || {!local _operator}
    || {!local group _driver} || {group _driver != group _operator}) exitWith {[]};
[_driver,_operator,currentCommand _driver,+(expectedDestination _driver),
    currentCommand _operator,+(expectedDestination _operator)]
