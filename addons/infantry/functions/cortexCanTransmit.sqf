/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Read-only, repeat-safe local query; no public mutation or JIP side effects.
 * Decides whether a soldier can pass information or call for support by radio.
 *
 * AI communications do not require an inventory radio item. Combat-ineffective actors
 * (including ACE unconsciousness and captivity) cannot reach the mission jamming hook;
 * conscious wounded soldiers remain eligible under the shared capability predicate.
 * Explicit server-registered CortexJammingField emitters deny AI radio within their
 * live3D radius/affected sides. Voice uses its separate path. No player radio state is changed.
 * Missions may also provide CBE_AITweaks_JammingFactor as a read-only CODE hook. A result of 0.5 or
 * more blocks AI reports, reinforcement calls and artillery requests. A missing hook adds no
 * further denial; native fields work independently of any external electronic-warfare addon.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: unit <OBJECT, default objNull>
 *
 * Return Value:
 * Boolean - true when the unit can transmit
 *
 * Example:
 * if ([leader _group] call CBE_fnc_CortexCanTransmit) then {...};
 * Result: a jammed squad leader cannot call for help.
 *
 * Current callers: Cortex contact reports, reinforcement, artillery, coordinated support and combined-arms opportunity selection.
 */

params [["_unit", objNull, [objNull]]];
if !([_unit] call CBE_fnc_CortexCombatEffective) exitWith {false};
private _position=getPosASL _unit;
private _side=side group _unit;
if ([_position,_side] call CBE_fnc_CortexJammingFactor >= 0.5) exitWith {false};
private _hook = missionNamespace getVariable ["CBE_AITweaks_JammingFactor", {0}];
if !(_hook isEqualType {}) exitWith {true};
private _factor = [_position,_side] call _hook;
// An optional provider may return nil while unavailable. Missing data means no jamming
// contribution; a numeric provider still controls the documented threshold.
if (isNil "_factor") exitWith {true};
_factor isEqualType 0 && {_factor < 0.5}

