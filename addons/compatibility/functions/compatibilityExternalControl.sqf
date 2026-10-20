/*
 * Author: WaldoTheWarfighter
 * Reads declared ownership and active specialist runtime markers through CBE's compatibility boundary.
 * Tactical subsystems use this neutral gate rather than depending on another product's runtime
 * variable name. The marker is read-only and never grants CBE ownership.
 *
 * Locality / Authority: Read-only; callable on any machine for a group or object.
 * Repeat/JIP: Safe to repeat. It reads the currently published marker each time and changes no state.
 * Unknown/non-boolean declared ownership is conservatively treated as external control.
 *
 * Arguments:
 * 0: subject <GROUP or OBJECT>, default grpNull - group or actor/vehicle to inspect.
 *
 * Return Value:
 * Boolean - true when subject/group declares external control, its declaration is malformed,
 * or an actor has a specialist runtime marker. Unknown state never grants CBE ownership.
 *
 * Current callers: CBE eligibility, vehicles, aircraft, skill layers, diagnostics and HC adoption.
 *
 * Example:
 * if ([group _unit] call CBE_fnc_CompatibilityExternalControl) exitWith {};
 */
params [["_subject", grpNull, [grpNull, objNull]]];

if (_subject isEqualType grpNull) exitWith {
    if (isNull _subject) exitWith {false};
    private _declared=_subject getVariable ["Waldo_AI_ExternalControl",false];
    !(_declared isEqualType true) || {_declared}
};
if (isNull _subject) exitWith {false};

private _declared=_subject getVariable ["Waldo_AI_ExternalControl",false];
private _groupDeclared=(group _subject) getVariable ["Waldo_AI_ExternalControl",false];
(!(_declared isEqualType true) || {_declared})
|| {!(_groupDeclared isEqualType true) || {_groupDeclared}}
// Runtime activation can occur while an engine danger response is waiting. These bounded
// marker reads permit immediate yielding without the full config/faction classifier.
|| {["WBK_AI_ISZombie","Droid_Health","WBK_Droids_VoiceType","WBK_AI_ZombieMoveSet",
     "IMS_IsUnitInvicibleScripted","IMS_ISAI","IMS_EventHandler_Hit"] findIf {
        !isNil {_subject getVariable _x}
    } >= 0}
|| {private _animation=toLowerANSI animationState _subject;
    _animation find "ims_" == 0 || {_animation find "star_wars_fight" == 0}}
