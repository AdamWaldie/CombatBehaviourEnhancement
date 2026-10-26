/*
 * Author: WaldoTheWarfighter
 * Reads a directly observed target using an active, visible assigned observer and its binoculars. No report is extrapolated.
 * Locality/authority: Read-only on the observer owner. Callers retain server mission-token
 * authority; this helper never selects weapons or changes watch, target or movement orders.
 * Repeat/JIP: Stateless; every call rechecks assignment, live native knowledge and visibility.
 * Existing binocular equipment is required, but a fix grants no weapon-selection authority.
 * Arguments: 0: spotter <OBJECT>; 1: enemy <OBJECT>; 2: previous impact ATL <ARRAY>, default [].
 * Return Value: Array [reported ATL, error], or [] without observation.
 * Current callers: ArtilleryRequest and ArtilleryObserve.
 * Example: private _fix = [_spotter, _enemy] call CBE_fnc_CortexSpotterFix;
 */
params [["_spotter", objNull, [objNull]], ["_enemy", objNull, [objNull]], ["_impact", [], [[]]]];
if (!local _spotter || {!alive _spotter} || {isPlayer _spotter} || {!alive _enemy}
    || {!(_spotter getVariable ["CBE_AIPass_Spotter", false])}
    || {!simulationEnabled _spotter} || {isObjectHidden _spotter}
    || {vehicle _spotter != _spotter} || {binocular _spotter == ""}
    || {_spotter getVariable ["ACE_isUnconscious", false]} || {lifeState _spotter == "INCAPACITATED"}
    || {!([group _spotter] call CBE_fnc_CortexIsEligible)}) exitWith {[]};
if (!([_spotter] call CBE_fnc_CortexCanTransmit)) exitWith {[]};
private _knowledge = _spotter targetKnowledge _enemy;
if (!(_knowledge select 1) || {_spotter knowsAbout _enemy < 1.5}
    || {time - (_knowledge select 2) > 5}
    // The observed object may be a vehicle, aircraft or static weapon. Its direct side is the
    // stable identity boundary; `group _enemy` is meaningful only for infantry and previously
    // rejected or misclassified combined-arms contacts before the observer could report them.
    || {(side group _spotter) getFriend (side _enemy) >= 0.6}) exitWith {[]};
private _eye = eyePos _spotter;
if ([_spotter, "VIEW", _enemy] checkVisibility [_eye, aimPos _enemy] < 0.5) exitWith {[]};
if (_impact isNotEqualTo [] && {[_spotter, "VIEW"] checkVisibility [_eye, (ATLToASL _impact) vectorAdd [0, 0, 1]] < 0.5}) exitWith {[]};
[_spotter getHideFrom _enemy, _knowledge select 5]
