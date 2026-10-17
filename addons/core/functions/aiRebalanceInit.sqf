/*
 * Author: WaldoTheWarfighter
 * Configures AI skill profiles once per machine and applies the selected profile to local AI.
 * Repeat/JIP: one repeat-safe lighting/seat worker refreshes ten registered local units per second;
 * unchanged lighting/equipment/vehicle seat causes no skill writes. Stop invalidates its queue generation; replay reinstalls one job.
 *
 * Existing local AI are processed immediately. A CBA CAManBase init handler catches newly created
 * units, including Zeus placements, and a per-unit Local event handler reapplies the active profile
 * after server/headless-client ownership changes. ACE Headless's documented post-transfer event is
 * also handled explicitly and acknowledged to the server. Players are never modified. The LINE profile is the
 * default baseline; its established values are intentionally retained rather than made harder.
 * Locality and authority: CBA selects the effective profile and replays it to joining owners.
 * A direct server call requesting different values uses the CBA server layer. Other owners cannot
 * change global configuration; each owner applies the effective values only to its local AI.
 *
 * Arguments:
 * 0: mode <STRING> - AUTO (default), DAY or NIGHT
 * 1: profile <STRING> - built-in or mission-defined profile key (default LINE)
 *
 * Return Value:
 * Boolean - true when the valid request is accepted, pending readiness, or applied locally
 *
 * Example:
 * ["NIGHT", "LINE"] call CBE_fnc_AIRebalanceInit;
 * Result: eligible existing and newly local AI use the LINE profile's low-light skill values.
 *
 * Current callers: AITweak startup wrapper, CBA setting callbacks, server scripts and audits.
 */

params [
    ["_mode", "AUTO", [""]],
    ["_profile", "LINE", [""]]
];
[] call CBE_fnc_CompatibilityHeadlessBridge;
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if !(missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]) exitWith {
    if (missionNamespace getVariable ["CBE_AI_RebalanceInitPending", false]) exitWith {true};
    missionNamespace setVariable ["CBE_AI_RebalanceInitPending", true];
    [] spawn {
        waitUntil {
            missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]
            || {!(missionNamespace getVariable ["CBE_AI_RebalanceInitPending", false])}
        };
        private _requested = missionNamespace getVariable ["CBE_AI_RebalanceInitPending", false];
        missionNamespace setVariable ["CBE_AI_RebalanceInitPending", false];
        if (_requested && {missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]}
            && {missionNamespace getVariable ["CBE_AIRebalance_Enable", false]}) then {
            [missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"],
                missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"]] call CBE_fnc_AIRebalanceInit;
        };
    };
    true
};

private _defaultProfiles = createHashMapFromArray [
        ["LEGACY", createHashMapFromArray [
            ["aimingSpeed", 0.42], ["aimingAccuracy", 0.83], ["aimingShake", 0.36],
            ["spotTime", 0.80], ["spotDistance", 1.00], ["commanding", 1.00],
            ["general", 1.00], ["courage", 0.90], ["reloadSpeed", 0.90]
        ]],
        ["PUBLIC", createHashMapFromArray [
            ["aimingSpeed", 0.35], ["aimingAccuracy", 0.20], ["aimingShake", 0.38],
            ["spotTime", 0.45], ["spotDistance", 0.55], ["commanding", 0.65],
            ["general", 0.60], ["courage", 0.65], ["reloadSpeed", 0.65]
        ]],
        ["MILITIA", createHashMapFromArray [
            ["aimingSpeed", 0.35], ["aimingAccuracy", 0.20], ["aimingShake", 0.38],
            ["spotTime", 0.45], ["spotDistance", 0.55], ["commanding", 0.65],
            ["general", 0.60], ["courage", 0.65], ["reloadSpeed", 0.65]
        ]],
        ["STANDARD", createHashMapFromArray [
            ["aimingSpeed", 0.48], ["aimingAccuracy", 0.30], ["aimingShake", 0.52],
            ["spotTime", 0.62], ["spotDistance", 0.70], ["commanding", 0.75],
            ["general", 0.72], ["courage", 0.78], ["reloadSpeed", 0.78]
        ]],
        ["LINE", createHashMapFromArray [
            ["aimingSpeed", 0.48], ["aimingAccuracy", 0.30], ["aimingShake", 0.52],
            ["spotTime", 0.62], ["spotDistance", 0.70], ["commanding", 0.75],
            ["general", 0.72], ["courage", 0.78], ["reloadSpeed", 0.78]
        ]],
        ["VETERAN", createHashMapFromArray [
            ["aimingSpeed", 0.62], ["aimingAccuracy", 0.42], ["aimingShake", 0.65],
            ["spotTime", 0.78], ["spotDistance", 0.84], ["commanding", 0.88],
            ["general", 0.88], ["courage", 0.90], ["reloadSpeed", 0.88]
        ]],
        ["ELITE", createHashMapFromArray [
            ["aimingSpeed", 0.72], ["aimingAccuracy", 0.52], ["aimingShake", 0.76],
            ["spotTime", 0.88], ["spotDistance", 0.92], ["commanding", 0.95],
            ["general", 0.95], ["courage", 0.96], ["reloadSpeed", 0.94]
        ]]
    ];
private _storedProfiles = missionNamespace getVariable ["CBE_AI_Profiles", createHashMap];
{
    if !(_x in (keys _storedProfiles)) then {_storedProfiles set [_x, _defaultProfiles get _x]};
} forEach keys _defaultProfiles;
missionNamespace setVariable ["CBE_AI_Profiles", _storedProfiles];

_mode = toUpperANSI _mode;
if !(_mode in ["AUTO","DAY","NIGHT"]) exitWith {false};
_profile = toUpperANSI _profile;
private _profiles = missionNamespace getVariable ["CBE_AI_Profiles", createHashMap];
if !(_profile in (keys _profiles)) exitWith {
    if (isServer) then {diag_log format ["[CBE AI] Unknown profile '%1'; AI rebalance was not changed.", _profile]};
    false
};

// Explicit server calls change CBA; callbacks apply only the effective owner-local state.
private _configurationChange = !(missionNamespace getVariable ["CBE_AIRebalance_Enable", true])
    || {_mode != (missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"])}
    || {_profile != (missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"])};
if (_configurationChange) exitWith {
    if (!isServer) exitWith {false};
    ([createHashMapFromArray [
        ["CBE_AIRebalance_Mode", _mode],
        ["CBE_AIRebalance_Profile", _profile],
        ["CBE_AIRebalance_Enable", true]
    ]] call CBE_fnc_CortexTuning) > 0
};
missionNamespace setVariable ["CBE_AI_RebalanceActive", true];

if !(missionNamespace getVariable ["CBE_AI_HandlerInstalled", false]) then {
    missionNamespace setVariable ["CBE_AI_HandlerInstalled", true];
    ["CAManBase", "init", {
        params ["_unit"];
        if !(_unit getVariable ["CBE_AI_LocalHandlerInstalled", false]) then {
            _unit setVariable ["CBE_AI_LocalHandlerInstalled", true];
            _unit addEventHandler ["Local", {
                params ["_unit", "_isLocal"];
                if (_isLocal && {missionNamespace getVariable ["CBE_AI_RebalanceActive", false]}) then {[_unit] call CBE_fnc_AIApplyProfile};
            }];
        };
        if (local _unit && {!isPlayer _unit} && {toUpperANSI (missionNamespace getVariable ["CBE_AI_ApplyMode", "BOTH"]) != "EXISTING"}) then {
            [_unit] call CBE_fnc_AIApplyProfile;
        };
    }, true, [], true] call CBA_fnc_addClassEventHandler;
};

// ACE Headless can be the active owner scheduler even when CBE's optional HC distributor is off.
// Its documented post-transfer event runs on the destination owner and reports whether the engine
// transfer actually succeeded. Adopt ordinary AI there instead of assuming CBE initiated the move.
if !(missionNamespace getVariable ["CBE_AI_ACEHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["CBE_AI_ACEHeadlessHandlerInstalled", true];
    ["ace_headless_groupTransferPost", {
        params ["_group", "_headlessEntity", "_previousOwner", "_newOwner", "_transferredSuccessfully"];
        // ACE raises this event on both the old locality and the destination HC. During the transfer
        // window `local _group` can still be true on the old owner, so the destination owner ID is
        // the authoritative gate. Without it, the server or a different HC can acknowledge work it
        // did not own (visible as sender/claimedOwner mismatches in dedicated-server diagnostics).
        if (_transferredSuccessfully && {isServer || {!hasInterface}} && {clientOwner == _newOwner}
            && {local _group} && {missionNamespace getVariable ["CBE_AI_RebalanceActive", false]}) then {
            // Reuse the common adoption path so an ACE transfer retires stale operation callbacks
            // and immediately reconstructs durable CBE intent as well as applying skills. The old
            // implementation only refreshed skills here, leaving active movement/clear/convoy work
            // dependent on a later discovery sweep.
            [_group, _previousOwner, _newOwner, "ACE"] call CBE_fnc_AIHeadlessAdoptLocal;
            private _adoption=_group getVariable ["CBE_AI_LastHeadlessAdoption",[]];
            private _applied=_adoption param [1,0];
            diag_log format ["[CBE AI] ACE HC adoption group=%1 previousOwner=%2 newOwner=%3 localUnits=%4 applied=%5 profile=%6/%7.",
                _group, _previousOwner, _newOwner, {local _x} count units _group, _applied,
                missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"],
                missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"]
            ];
            if (_newOwner >= 2) then {
                [_group, _headlessEntity, _previousOwner, _newOwner, _applied,
                    missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"],
                    missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"]
                ] remoteExecCall ["CBE_fnc_AIHeadlessAdoptionResultServer", 2];
            };
        };
    }] call CBA_fnc_addEventHandler;
};

// CBE provides the same post-transfer contract when its native headless manager is the sole
// distributor.  Listening to its public event makes CBE follow an already-authoritative move;
// CBE never registers an HC, selects a destination, or starts a second balancing loop.
if !(missionNamespace getVariable ["CBE_AI_CompatibilityHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["CBE_AI_CompatibilityHeadlessHandlerInstalled", true];
    ["CBE_Compatibility_HeadlessMigrated", {
        params ["_group", "_previousOwner", "_newOwner", "_provider"];
        if ((isServer || {!hasInterface}) && {clientOwner == _newOwner} && {local _group}
            && {missionNamespace getVariable ["CBE_AI_RebalanceActive", false] || {missionNamespace getVariable ["CBE_AIPass_Active", false]}}) then {
            [_group, _previousOwner, _newOwner, _provider] call CBE_fnc_AIHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};

if (toUpperANSI (missionNamespace getVariable ["CBE_AI_ApplyMode", "BOTH"]) != "NEW") then {
    {
        if !(_x getVariable ["CBE_AI_LocalHandlerInstalled", false]) then {
            _x setVariable ["CBE_AI_LocalHandlerInstalled", true];
            _x addEventHandler ["Local", {
                params ["_unit", "_isLocal"];
                if (_isLocal && {missionNamespace getVariable ["CBE_AI_RebalanceActive", false]}) then {[_unit] call CBE_fnc_AIApplyProfile};
            }];
        };
        if (local _x && {!isPlayer _x}) then {[_x] call CBE_fnc_AIApplyProfile};
    } forEach allUnits;
};

// Skills share the same bounded scheduler as tactics. Generation ownership prevents duplicate
// refresh jobs and makes queued work harmless after disable/re-enable.
if !(missionNamespace getVariable ["CBE_AI_LightingQueued", false]) then {
    missionNamespace setVariable ["CBE_AI_LightingQueued", true];
    private _state = createHashMapFromArray [
        ["subsystem", "SKILLS"],
        ["generation", missionNamespace getVariable ["CBE_AI_LightingGeneration", 0]]
    ];
    [CBE_fnc_AILightingStep, _state, 1] call CBE_fnc_CortexQueueJob;
};
[] call CBE_fnc_SchedulerReconcile;
if (isServer) then {diag_log format ["[CBE AI] %1 profile active in %2 mode.", _profile, _mode]};
true
