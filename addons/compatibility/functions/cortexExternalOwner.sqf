/*
 * Author: WaldoTheWarfighter
 * Identifies AI whose movement, animation or combat state belongs to a supported external system.
 * CBE uses this one read-only gate before any tactic so specialist skeletons, creatures, droids and
 * active melee actors never receive competing movement, animation or damage commands.
 * Ordinary infantry remains eligible when those addons are merely loaded. Verified active
 * rappelling markers also yield actor/vehicle control, without assuming descent completion.
 *
 * Locality / Authority: callable anywhere. Classification changes no actor, provider or public
 * state; only the bounded machine-local class memo is populated.
 * Repeat/JIP: repeat-safe; live runtime markers are read on every call. A machine-local
 * cache retains at most256 immutable class classifications; overflow computes without storing.
 * No actor/provider/public state changes, new worker or locality replay.
 *
 * Arguments:
 * 0: actor <OBJECT>, default objNull
 *
 * Return Value:
 * String - empty when Cortex may proceed; otherwise the external owner identifier.
 *
 * Current callers: CBE_fnc_CortexIsEligible and AI diagnostics.
 *
 * Example:
 * private _owner = [_unit] call CBE_fnc_CortexExternalOwner;
 * Result: "SPECIALIST" for a specialist droid and "" for an ordinary NATO rifleman.
 */

params [["_unit",objNull,[objNull]]];
if (isNull _unit) exitWith {""};

// Verified Advanced Rappelling actor and bulk-helicopter ownership markers.
// False/absent does not exclude ordinary AI; never clear a provider's active state.
if (["AR_Is_Rappelling","AR_Units_Rappelling"] findIf {
    private _active=_unit getVariable [_x,false];
    !(_active isEqualType true) || {_active}
} >= 0) exitWith {"RAPPEL"};

private _wbkMarker=!(isNil {_unit getVariable "WBK_AI_ISZombie"})
    || {!(isNil {_unit getVariable "Droid_Health"})}
    || {!(isNil {_unit getVariable "WBK_Droids_VoiceType"})}
    || {!(isNil {_unit getVariable "WBK_AI_ZombieMoveSet"})};
if (_wbkMarker) exitWith {"SPECIALIST"};

// Config identity is immutable for this mission; cache only that classification.
// Live runtime markers above and melee/animation below are never cached.
private _class=typeOf _unit;
if (isNil "CBE_ExternalOwnerClassCache") then {CBE_ExternalOwnerClassCache=createHashMap};
private _static=CBE_ExternalOwnerClassCache getOrDefault [_class,-1];
if (_static isEqualTo -1) then {
    private _config=configOf _unit;
    private _faction=getText (_config >> "faction");
    private _author=toLowerANSI (getText (_config >> "author"));
    private _subcategory=getText (_config >> "editorSubcategory");
    private _wbkFactions=[
        "WBK_AI_ZHAMBIES","WBK_AI_StarWars_Droids","WBK_AI","WBK_AI_Melee",
        "WBK_EOO_Secession","WBK_EOO_Vamp","Empires_Of_Old_faction_Vamp",
        "WBK_EOO_FreeCompany","WBK_EOO_Empire","WBK_HL_Aliens","WBK_HL_resistance",
        "WBK_HL_Combines","OPTRE_FC_Covenant","dev_flood","dev_mutants"
    ];
    // Custom movement config alone remains insufficient evidence of specialist ownership.
    _static=_class find "WBK_" == 0 || {_faction in _wbkFactions}
        || {_subcategory == "WBK_MeleeAi_SPACE_MARINES"} || {_author find "webknight" >= 0};
    if (count CBE_ExternalOwnerClassCache < 256) then {CBE_ExternalOwnerClassCache set [_class,_static]};
};
if (_static) exitWith {"SPECIALIST"};

// external controller only owns an actor while its melee runtime says so. Loading external controller must not exclude every rifleman.
private _animation=toLowerANSI animationState _unit;
private _meleeBackendActive=!(isNil {_unit getVariable "IMS_IsUnitInvicibleScripted"})
    || {!(isNil {_unit getVariable "IMS_ISAI"})}
    || {!(isNil {_unit getVariable "IMS_EventHandler_Hit"})}
    || {_animation find "ims_" == 0}
    || {_animation find "star_wars_fight" == 0};
if (_meleeBackendActive) exitWith {"MELEE"};

""
