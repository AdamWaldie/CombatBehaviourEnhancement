/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Machine-local start guard prevents duplicate scheduler and handlers. Joining owners install their own local runtime.
 * Starts the Smart AI Pass on this machine if it owns AI: the server or a headless client.
 *
 * Installs, once per machine:
 * - one CBA per-frame handler that runs CBE_fnc_CortexSchedulerTick. The due-time cache makes
 *   idle frames constant-time; due work gets one budgeted opportunity per rendered/simulated frame
 *   instead of being capped at four heavy jobs per second;
 * - one EntityKilled mission handler retains up to64 death identities for the current finite
 *   clearance episode, separately from up to eight five-minute own-group casualty
 *   identities and passes kills to survivor regroup. Exact clearance context can corroborate a
 *   deleted exterior guard; public provenance alone never dispatches movement. A current
 *   visible death in a civilian group of at most16 may request the existing finite refuge
 *   response for local witnesses within45m; at most16 terrain/VIEW ray pairs, no world scan;
 * - the CBE_fnc_CortexDiscover sweep job, which brings local groups under the pass;
 * - a ProjectileCreated handler for grenade evasion, only while CBE_AIPass_GrenadeEvasion_Enable is
 *   on (it would otherwise run for every projectile);
 * - a shared ArtilleryShellFired handler for native firing evidence and counter-battery;
 *   counter-battery admission reads its live enable switch independently of evidence collection.
 * - event-driven civilian FiredNear/Hit reactions when enabled. Existing and newly created owner-local
 *   civilians are versioned once; no civilian polling loop is installed.
 * Existing local groups have their peak strength recorded. Repeat calls are safe, and they add the
 * optional handlers when their switches have been turned on since the last call. Player clients return immediately and pay nothing. Each
 * behaviour has its own CBE_AIPass_<Behaviour>_Enable switch in \z\cbe\addons\main\settings\aiConfig.sqf, and
 * CBE_fnc_CortexIsEligible keeps player groups and other CBE features' units out.
 * CBE's configured danger FSM must own all three base-soldier slots. If another addon replaces any
 * slot, this tactical runtime fails closed instead of running a second infantry brain beside it.
 * Movement ownership is reserved only for finite CBE operations.
 * Locality and authority: CBA supplies the effective enable value to every joining owner. A direct
 * server call while disabled requests enable through the CBA server layer; callbacks install local
 * work. Remote calls from anything other than the server are refused. A headless client waits for
 * CBA settings readiness first.
 *
 * Review contract: Repeated pre-snapshot calls share one waiter. Stop cancels it; a headless client starts only if the completed authoritative snapshot still enables the pass.
 *
 * Arguments: None.
 *
 * Return Value:
 * Boolean - true when startup is accepted, pending settings readiness, or already running
 *
 * Example:
 * [] call CBE_fnc_CortexInit;
 * Result: on the server, the pass starts and every connected or later headless client starts it too.
 *
 * Current callers: addon postInit, CBA setting callbacks, server scripts and audits.
 */

if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (hasInterface && {!isServer}) exitWith {false};
if !(missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]) exitWith {
    if (missionNamespace getVariable ["CBE_AIPass_InitPending", false]) exitWith {true};
    missionNamespace setVariable ["CBE_AIPass_InitPending", true];
    [] spawn {
        waitUntil {
            missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]
            || {!(missionNamespace getVariable ["CBE_AIPass_InitPending", false])}
        };
        private _requested = missionNamespace getVariable ["CBE_AIPass_InitPending", false];
        missionNamespace setVariable ["CBE_AIPass_InitPending", false];
        if (_requested && {missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]}
            && {missionNamespace getVariable ["CBE_AIPass_Enable", false]}) then {[] call CBE_fnc_CortexInit};
    };
    true
};

// A direct server start is a configuration request. CBA callbacks start each owner locally.
if !(missionNamespace getVariable ["CBE_AIPass_Enable", false]) exitWith {
    if (!isServer) exitWith {false};
    ([createHashMapFromArray [["CBE_AIPass_Enable", true]]] call CBE_fnc_CortexTuning) > 0
};
private _dangerFsmPaths=["SoldierWB","SoldierEB","SoldierGB"] apply {
    [_x,toLowerANSI getText (configFile >> "CfgVehicles" >> _x >> "fsmDanger")]
};
private _dangerFsmOwned=_dangerFsmPaths findIf {
    (_x select 1) find "z\cbe\addons\danger\danger.fsm" < 0
} < 0;
missionNamespace setVariable ["CBE_AIPass_DangerOwnershipConflict",[[],_dangerFsmPaths] select !_dangerFsmOwned];
if (!_dangerFsmOwned) exitWith {
    missionNamespace setVariable ["CBE_AIPass_Active",false];
    diag_log format ["[CBE] Infantry tactical runtime refused: CBE does not own every base-soldier fsmDanger slot (%1).",_dangerFsmPaths];
    false
};
missionNamespace setVariable ["CBE_AIPass_Active", true];

[] call CBE_fnc_SchedulerReconcile;
if (isNil {missionNamespace getVariable "CBE_AIPass_KilledHandler"}) then {
    missionNamespace setVariable ["CBE_AIPass_KilledHandler", addMissionEventHandler ["EntityKilled", {
        params ["_unit"];
        if !(missionNamespace getVariable ["CBE_AIPass_Active", false]) exitWith {};
        if !(_unit isKindOf "CAManBase") exitWith {};
        private _group = group _unit;
        if (isNull _group || {!local _group}) exitWith {};
        // Retain identity from the actual death event, before later corpse/group detachment.
        // This is provenance only; a fresh native casualty observation still gates body inspection.
        private _casualties=_group getVariable ["CBE_Danger_Casualties",[]];
        if !(_casualties isEqualType []) then {_casualties=[]};
        _casualties=(_casualties select [0,8]) select {
            _x isEqualType [] && {count _x == 5} && {(_x select 0) isEqualType objNull}
                && {isNull (_x select 0) || {!alive (_x select 0)}}
                && {(_x select 3) isEqualType ""} && {(_x select 4) isEqualType []}
                && {count (_x select 4) in [0,4]}
                && {!isNull (_x select 0) || {(_x select 3) != "" && {(_x select 3) != "0:0"}
                    && {count (_x select 4) == 4}}}
                && {(_x select 1) isEqualType 0} && {finite (_x select 1)}
                && {(_x select 2) isEqualType 0} && {finite (_x select 2)}
                && {(_x select 1) <= serverTime} && {(_x select 2) > serverTime}
                && {(_x select 2) > (_x select 1)} && {(_x select 2) <= (_x select 1)+300}
        };
        if (_casualties findIf {(_x select 0) == _unit} < 0) then {
            if (count _casualties >= 8) then {_casualties deleteAt 0};
            // Keep positive death identity for this exact clearance even after corpse
            // deletion. Missing object lookup alone never establishes a casualty.
            private _clearContext=_group getVariable ["CBE_Cortex_ClearVisitContext",[]];
            private _clearOperation=_group getVariable ["CBE_Operation",createHashMap];
            if (!(_clearContext isEqualType []) || {count _clearContext != 4}
                || {(_clearOperation getOrDefault ["intent",""]) != "CLEAR"}
                || {(_clearOperation getOrDefault ["phase",""]) == "CANCELLED"}
                || {(_clearOperation getOrDefault ["objective",objNull]) isNotEqualTo (_clearContext select 0)}) then {_clearContext=[]};
            // Clearance loss provenance must outlive the rolling body-observation list.
            // Keep only actual death identities, tied to the original finite episode;
            // corpse removal or later deaths cannot manufacture or evict its first losses.
            private _deathId=netId _unit;
            if (count _clearContext == 4 && {!(_deathId in ["","0:0"])}
                && {(_clearContext select 2) isEqualType 0} && {finite (_clearContext select 2)}
                && {serverTime < (_clearContext select 2)}) then {
                private _losses=_group getVariable ["CBE_Cortex_ClearLosses",[]];
                private _ids=[];
                if (_losses isEqualType [] && {count _losses == 2}
                    && {(_losses select 0) isEqualTo _clearContext}
                    && {(_losses select 1) isEqualType []} && {count (_losses select 1) <= 64}
                    && {(_losses select 1) findIf {!(_x isEqualType "") || {_x in ["","0:0"]}} < 0}) then {
                    _ids=+(_losses select 1);
                };
                if (!(_deathId in _ids) && {count _ids < 64}) then {
                    _ids pushBack _deathId;
                    _group setVariable ["CBE_Cortex_ClearLosses",[+_clearContext,_ids],true];
                };
            };
            _casualties pushBack [_unit,serverTime,serverTime+300,netId _unit,+_clearContext];
            _group setVariable ["CBE_Danger_Casualties",_casualties,true];
            // A death event is not shared perception. Only a current local civilian
            // who can see this own-group casualty receives the finite refuge cue.
            // Use the bounded existing roster, not allDeadMen/nearby-world discovery.
            if (side _group == civilian && {!isObjectHidden _unit}
                && {missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true]}
                && {!([] call CBE_fnc_CortexIsPaused)}) then {
                private _witnesses=units _group;
                if (count _witnesses <= 16) then {
                    private _bodyATL=getPosATL _unit;
                    private _bodyASL=(getPosASL _unit) vectorAdd [0,0,0.5];
                    private _radius=(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Radius",45]) max 0 min 45;
                    {
                        private _witness=_x;
                        private _active=_witness getVariable ["CBE_Cortex_CivilianReaction",[]];
                        // Coalesce casualties behind an equal/stronger live reaction.
                        // No repeated searches or renewed deadlines from the same death.
                        private _reacting=_active isNotEqualTo []
                            && {serverTime < (_active param [0,0,[0]])}
                            && {(_active param [1,0,[0]]) >= 2};
                        if (!_reacting && {_witness != _unit} && {local _witness}
                            && {alive _witness} && {!isPlayer _witness}
                            && {simulationEnabled _witness} && {!isObjectHidden _witness}
                            && {isNull objectParent _witness}
                            && {primaryWeapon _witness == "" && {secondaryWeapon _witness == ""} && {handgunWeapon _witness == ""}}
                            && {_witness distance _bodyATL <= _radius}) then {
                            private _eye=eyePos _witness;
                            private _towardBody=vectorNormalized (_bodyASL vectorDiff _eye);
                            // A clear ray behind the actor is not a visual witness.
                            if ((eyeDirection _witness) vectorDotProduct _towardBody >= 0.25
                                && {!terrainIntersectASL [_eye,_bodyASL]}
                                && {lineIntersectsSurfaces [_eye,_bodyASL,_witness,_unit,true,1,"VIEW","NONE"] isEqualTo []}) then {
                                // Supply only the observed casualty location, never killer identity.
                                [_witness,_bodyATL,"CASUALTY",2] call CBE_fnc_CortexCivilianReact;
                            };
                        };
                    } forEach _witnesses;
                };
            };
        };
        [_group, _unit] call CBE_fnc_CortexRegroupOnKill;
    }]];
};

if (!(missionNamespace getVariable ["CBE_AIPass_GrenadeEvasion_Enable", true]) && {!isNil {missionNamespace getVariable "CBE_AIPass_ProjectileHandler"}}) then {
    removeMissionEventHandler ["ProjectileCreated", missionNamespace getVariable "CBE_AIPass_ProjectileHandler"];
    missionNamespace setVariable ["CBE_AIPass_ProjectileHandler", nil];
};
if (isNil {missionNamespace getVariable "CBE_AIPass_ProjectileHandler"} && {missionNamespace getVariable ["CBE_AIPass_GrenadeEvasion_Enable", true]}) then {
    missionNamespace setVariable ["CBE_AIPass_ProjectileHandler", addMissionEventHandler ["ProjectileCreated", {
        params ["_projectile"];
        if !(missionNamespace getVariable ["CBE_AIPass_Active", false]) exitWith {};
        private _type = typeOf _projectile;
        private _cache = missionNamespace getVariable ["CBE_AIPass_GrenadeTypes", createHashMap];
        private _isGrenade = _cache getOrDefault [_type, -1];
        if (_isGrenade isEqualTo -1) then {
            _isGrenade = getText (configFile >> "CfgAmmo" >> _type >> "simulation") == "shotGrenade";
            _cache set [_type, _isGrenade];
            missionNamespace setVariable ["CBE_AIPass_GrenadeTypes", _cache];
        };
        if (_isGrenade) then {
            [CBE_fnc_CortexGrenadeCheck, createHashMapFromArray [["projectile", _projectile]], 0.3 + random 0.4] call CBE_fnc_CortexQueueJob;
        };
    }]];
};
if (isNil {missionNamespace getVariable "CBE_AIPass_ArtilleryHandler"}) then {
    missionNamespace setVariable ["CBE_AIPass_ArtilleryHandler", addMissionEventHandler ["ArtilleryShellFired", {
        _this call CBE_fnc_CortexArtilleryFired;
        params ["_vehicle", "", "", "_gunner"];
        if (missionNamespace getVariable ["CBE_AIPass_Active", false]) then {[_vehicle, _gunner] call CBE_fnc_CortexCounterBattery};
    }]];
};
// Optional addon public APIs can appear during postInit, so refresh the capability map before the
// first owner-local behaviour is accepted. Detection never changes another addon's state.
[] call CBE_fnc_AITweaksDetectCompatibility;
[] call CBE_fnc_CompatibilityHeadlessBridge;

// HC distribution remains owned by the active provider. CBE only adopts a group after the
// provider confirms that the engine made it local to this HC; that retires old-owner jobs and
// restarts bounded discovery without choosing a destination or moving the group itself. These
// handlers live with the tactical runtime so headless continuation also works when skill tuning is
// disabled.
if !(missionNamespace getVariable ["CBE_AI_ACEHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["CBE_AI_ACEHeadlessHandlerInstalled", true];
    ["ace_headless_groupTransferPost", {
        params ["_group", "_headlessEntity", "_previousOwner", "_newOwner", "_transferredSuccessfully"];
        if (_transferredSuccessfully && {isServer || {!hasInterface}} && {clientOwner == _newOwner}
            && {local _group} && {missionNamespace getVariable ["CBE_AIPass_Active", false]}) then {
            [_group, _previousOwner, _newOwner, "ACE"] call CBE_fnc_AIHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
if !(missionNamespace getVariable ["CBE_AI_CompatibilityHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["CBE_AI_CompatibilityHeadlessHandlerInstalled", true];
    ["CBE_Compatibility_HeadlessMigrated", {
        params ["_group", "_previousOwner", "_newOwner", "_provider"];
        if ((isServer || {!hasInterface}) && {clientOwner == _newOwner} && {local _group}
            && {missionNamespace getVariable ["CBE_AIPass_Active", false]}) then {
            [_group, _previousOwner, _newOwner, _provider] call CBE_fnc_AIHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
if (missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true]) then {
    {if (local _x) then {[_x] call CBE_fnc_CortexCivilianSetup}} forEach (allUnits select {side group _x == civilian});
    if (isNil {missionNamespace getVariable "CBE_Cortex_CivilianCreatedHandler"}) then {
        missionNamespace setVariable ["CBE_Cortex_CivilianCreatedHandler",addMissionEventHandler ["EntityCreated",{
            params ["_entity"];
            if (_entity isKindOf "CAManBase" && {local _entity}) then {[_entity] call CBE_fnc_CortexCivilianSetup};
        }]];
    };
} else {
    private _civilianCreated=missionNamespace getVariable "CBE_Cortex_CivilianCreatedHandler";
    if (!isNil "_civilianCreated") then {
        removeMissionEventHandler ["EntityCreated",_civilianCreated];
        missionNamespace setVariable ["CBE_Cortex_CivilianCreatedHandler",nil];
    };
    {if (local _x) then {[_x,true] call CBE_fnc_CortexCivilianSetup}} forEach (allUnits select {side group _x == civilian});
};
{
    if (local _x) then {
        _x setVariable ["CBE_AIPass_PeakSize", (_x getVariable ["CBE_AIPass_PeakSize", 0]) max ({alive _x} count units _x)];
    };
} forEach allGroups;
if !(missionNamespace getVariable ["CBE_AIPass_DiscoveryQueued", false]) then {
    missionNamespace setVariable ["CBE_AIPass_DiscoveryQueued", true];
    [CBE_fnc_CortexDiscover, createHashMap, 1] call CBE_fnc_CortexQueueJob;
};

diag_log format ["[CBE] Started on %1 (contact=%2 flank=%3 regroup=%4 artillery=%5 airborne=%6 dangerFSM=CBE meleeBackend=%7 specialistBackend=%8).",
    ["headless client", "server"] select isServer,
    missionNamespace getVariable ["CBE_AIPass_Contact_Enable", true],
    missionNamespace getVariable ["CBE_AIPass_Flank_Enable", true],
    missionNamespace getVariable ["CBE_AIPass_Regroup_Enable", true],
    missionNamespace getVariable ["CBE_AIPass_Artillery_Enable", false],
    missionNamespace getVariable ["CBE_AIPass_Airborne_Enable", false],
    missionNamespace getVariable ["CBE_AIPass_MeleeBackendLoaded",false],
    missionNamespace getVariable ["CBE_AIPass_SpecialistBackendLoaded",false]
];
true
