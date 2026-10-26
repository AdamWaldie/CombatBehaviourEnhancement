/*
 * Author: WaldoTheWarfighter
 * Native selected-weapon round/magazine loading, FIREWEAPON and fleeing gate all throws; fragmentation additionally retains current
 * group and individual YELLOW/RED fire permission at admission and every queued callback.
 * Admission, queue commitment and every delayed aim/release retry yield to hidden or
 * simulation-disabled actors and queued medical treatment; no queue or deadline is changed.
 * Makes one soldier throw a smoke or fragmentation grenade he is carrying, towards a position.
 *
 * Grenade types are identified from config, so mod grenades work: smoke is ammo simulation shotSmoke
 * or shotSmokeX; fragmentation is shotGrenade. Chemlights and ACE
 * flashbangs are skipped. The throw muzzle is the "Throw" weapon muzzle that accepts that magazine.
 * The queued throw revalidates ownership and requests target observation once per generation.
 * Alignment retries observe the original request without replaying doWatch or renewing its deadline. Release requires actual
 * body and viewing alignment; an unaligned actor cancels rather than throwing behind contact. A fragmentation grenade is never thrown when a
 * friendly, civilian, captive, surrendering or handcuffed soldier is within max(12 m, four times the selected ammo indirectHitRange) of the target. The thrower
 * must also remain outside that radius; invalid ammo radii are refused. The target cannot be under 8 m or over
 * 40 m away. Engine AI already treat smoke particles as blocking sight.
 * Locality and authority: call where the unit is local (forceWeaponFire is local-argument).
 *
 * Repeat/JIP: a maximum 1.5-second aiming window with 0.25-second retries rechecks ownership, medical/captivity status, Zeus takeover, drill replacement/cancellation, ammunition and frag safety;
 * Replacement operation generations, owner epochs and native protected tasks cancel queued throws.
 * Danger smoke rechecks the shared typed movement reservation at every queued release/retry;
 * unknown or malformed leases remain reserved and cancel before facing or weapon commands.
 * A cancelled queued fragmentation throw records its drill token so assault may continue without it.
 * Pending throws are not replayed to joining clients. Fragmentation throws track the actual projectile
 * locally for assault sequencing; that FiredMan handler removes itself or expires after ten seconds.
 * One additional three-second listener records native launch velocity for smoke and fragmentation;
 * zero horizontal velocity is marked unavailable, not interpreted as an observed bearing. Locality
 * changes retire the listener. Release evidence also records retained contact and launch error
 * against that contact, separating a wrong requested target from a wrong native release direction.
 * Actual FiredMan release additionally records body/view alignment, stance and animation;
 * command-time alignment alone is not treated as release-time proof.
 * Neither listener changes the projectile or creates recurring work.
 * Arguments:
 * 0: unit <OBJECT>
 * 1: towards <ARRAY> - ATL position
 * 2: kind <STRING> - "SMOKE" or "FRAG" (optional, default: "SMOKE")
 * 3: context <ARRAY> - optional ["DANGER", generation, expiry] or
 *    ["DRILL", group, originalToken, operationGeneration, ownerEpoch] cancellation contract.
 * Explicit DRILL context is checked before queue markers, each queued aiming retry and
 * final listener/native release. It never adopts the current token of a replacement task.
 *
 * Return Value:
 * Boolean - true when a carried grenade was queued; FiredMan/projectile evidence confirms deployment
 *
 * Example:
 * [_unit, _enemyPos, "FRAG"] call CBE_fnc_CortexThrowGrenade;
 * Result: the lead assaulter throws a grenade before the final rush.
 *
 * Current callers: CBE_fnc_CortexFlankStep, CBE_fnc_CortexRetreat and CBE_fnc_DangerSmokeStep.
 */

params [["_unit", objNull, [objNull]], ["_towards", [], [[]]], ["_kind", "SMOKE", [""]], ["_context",[],[[]]]];
if (isNull _unit || {!alive _unit} || {!local _unit} || {!simulationEnabled _unit} || {isObjectHidden _unit}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []} || {isPlayer _unit} || {!isNull remoteControlled _unit} || {vehicle _unit != _unit} || {count _towards < 2}) exitWith {false};
if (!([_unit] call CBE_fnc_CortexCombatEffective)
    || {([_unit] call CBE_fnc_CortexExternalOwner) != ""}
    || {[_unit] call CBE_fnc_CompatibilityExternalControl}) exitWith {false};
_kind=toUpperANSI _kind;
if (!(_kind in ["SMOKE","FRAG"]) || {!([group _unit] call CBE_fnc_CortexIsEligible)}) exitWith {false};
// Carry this stateless policy with the callback, rather than borrowing caller locals later.
// Smoke does not acquire lethal fire permission; it still respects explicit weapon disable.
private _fireAllowed={
    params ["_actor","_type"];
    private _allowed=_actor checkAIFeature "FIREWEAPON" && {!fleeing _actor}
        && {_type != "FRAG" || {unitCombatMode _actor in ["YELLOW","RED"]
            && {combatMode group _actor in ["YELLOW","RED"]}}};
    if (!_allowed) exitWith {false};
    // A throw must not replace native round/magazine loading. Read the selected
    // weapon only; no selection, reload command or extra worker is needed.
    // Phase-1 means a removed magazine, not a running reload. Permit that exact
    // empty state, including an unarmed actor, when magazine loading is settled.
    private _native=weaponState _actor;
    _native isEqualType [] && {count _native >= 7}
        && {[0,1,2,3] findIf {!((_native select _x) isEqualType "")} < 0}
        && {[4,5,6] findIf {!((_native select _x) isEqualType 0)
            || {!finite (_native select _x)}} < 0}
        && {(_native select 4) >= 0} && {(_native select 6) == 0}
        && {(_native select 5) == 0 || {(_native select 5) == -1
            && {(_native select 3) == ""} && {(_native select 4) == 0}}}
};
if !([_unit,_kind] call _fireAllowed) exitWith {false};
// Explicit finite callers must not adopt a replacement drill discovered during selection.
// This local validator travels with queued callbacks; it captures no expired caller locals.
private _contextMatches={
    params ["_actor","_required"];
    if (_required isEqualTo [] || {(_required select 0) isNotEqualTo "DRILL"}) exitWith {true};
    if (count _required != 5 || {!((_required select 1) isEqualType grpNull)}
        || {!((_required select 2) isEqualType "")} || {(_required select 2) == ""}
        || {!((_required select 3) isEqualType 0)} || {!finite (_required select 3)}
        || {!((_required select 4) isEqualType 0)} || {!finite (_required select 4)}
        || {(_required select 3) < 0} || {(_required select 4) < 0}) exitWith {false};
    _required params ["","_group","_token","_generation","_epoch"];
    if (isNull _group || {!local _group} || {group _actor != _group}
        || {(_group getVariable ["CBE_OperationGeneration",-1]) != _generation}
        || {(_group getVariable ["CBE_AIPass_Epoch",-1]) != _epoch}) exitWith {false};
    private _drill=(_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap];
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _parentGate=if ((_drill getOrDefault ["supportToken",""]) != "") then {
        "CBE_AIPass_CoordinatedAssault_Enable"
    } else {
        switch (_drill getOrDefault ["type","FLANK"]) do {
            case "ADVANCE": {"CBE_AIPass_Advance_Enable"};
            case "ASSAULT": {"CBE_AIPass_Assault_Enable"};
            default {"CBE_AIPass_Flank_Enable"};
        }
    };
    missionNamespace getVariable ["CBE_AIPass_Enable",false]
        && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {!([] call CBE_fnc_CortexIsPaused)}
        && {[_group,_parentGate,true] call CBE_fnc_CortexFeatureEnabled}
        && {(_drill getOrDefault ["token",""]) == _token}
        && {(_drill getOrDefault ["operationGeneration",-2]) == _generation}
        && {(_drill getOrDefault ["ownerEpoch",-2]) == _epoch}
        && {(_operation getOrDefault ["generation",-2]) == _generation}
        && {(_operation getOrDefault ["ownerEpoch",-2]) == _epoch}
        && {(_operation getOrDefault ["phase",""]) != "CANCELLED"}
};
if !([_unit,_context] call _contextMatches) exitWith {false};
private _simulations = if (_kind == "FRAG") then {["shotGrenade"]} else {["shotSmoke", "shotSmokeX"]};
if (toUpperANSI _kind == "FRAG") then {
    private _distance = _unit distance2D _towards;
    if (_distance < 8 || {_distance > 40}) exitWith {_simulations = []};

};
if (_simulations isEqualTo []) exitWith {false};
private _throwConfig = configFile >> "CfgWeapons" >> "Throw";
private _muzzles = getArray (_throwConfig >> "muzzles");
private _thrown = false;
{
    private _magazine = _x;
    private _ammo = getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
    private _ammoConfig = configFile >> "CfgAmmo" >> _ammo;
    // Chemlights inherit from SmokeShell and ACE flashbangs use the grenade simulations: neither is
    // the smoke screen or fragmentation grenade the drill asked for.
    if (getText (_ammoConfig >> "simulation") in _simulations
        && {!(_ammo isKindOf ["Chemlight_base", configFile >> "CfgAmmo"])}
        && {getNumber (_ammoConfig >> "ace_grenades_flashbang") != 1}) then {
        private _muzzleIndex = _muzzles findIf {_magazine in getArray (_throwConfig >> _x >> "magazines")};
        if (_kind == "FRAG" && {_muzzleIndex >= 0}) then {
            private _blastRange=getNumber (_ammoConfig >> "indirectHitRange");
            private _safetyRadius=12 max (4*_blastRange);
            // Engine indirect damage can extend to four times its configured base radius.
            // Reject malformed data and unsafe ammo before turning or queuing this actor.
            if (!finite _blastRange || {_blastRange < 0} || {!finite _safetyRadius}
                || {_unit distance2D _towards <= _safetyRadius}
                || {(_towards nearEntities ["CAManBase",_safetyRadius]) findIf {
                    private _otherSide=side group _x;
                    alive _x && {captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
                        || {_x getVariable ["ace_captives_isHandcuffed",false]}
                        || {_otherSide == civilian} || {(side group _unit) getFriend _otherSide >= 0.6}}
                } >= 0}) then {_muzzleIndex=-1};
        };
        if (_muzzleIndex >= 0) then {
            isNil {
            if (!([_unit,_context] call _contextMatches) || {!local _unit}
                || {!simulationEnabled _unit} || {isObjectHidden _unit}
                || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
                || {!([_unit] call CBE_fnc_CortexCombatEffective)}
                || {!([_unit,_kind] call _fireAllowed)}
                || {!([group _unit] call CBE_fnc_CortexIsEligible)}) exitWith {};
            private _muzzle = _muzzles select _muzzleIndex;
            // A throw leaves along the unit's current facing. Do not alter facing until the queued
            // release has revalidated CBE, Zeus, specialist, generation and ammunition ownership.
            if (_kind == "FRAG") then {_unit setVariable ["CBE_Cortex_FragCancelled",nil]};
            private _drillToken=(((group _unit) getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]) getOrDefault ["token",""];
            private _throwGeneration=(_unit getVariable ["CBE_Cortex_ThrowGeneration",0])+1;
            _unit setVariable ["CBE_Cortex_ThrowGeneration",_throwGeneration];
            _unit setVariable ["CBE_Cortex_ThrowDecision",[time,"QUEUED",_kind,_throwGeneration]];
            private _operationGeneration=(group _unit) getVariable ["CBE_OperationGeneration",0];
            private _ownerEpoch=(group _unit) getVariable ["CBE_AIPass_Epoch",0];
            private _release = {
                params ["_unit", "_muzzle", "_magazine", "_group", "_hold", "_kind", "_towards", "_drillToken", "_context", "_expires", "_retry", "_throwGeneration", "_operationGeneration", "_ownerEpoch", "_contextMatches", "_fireAllowed", ["_aimIssued",false,[true]]];
                // A newer request supersedes this queued attempt without cancelling its frag token.
                if ((_unit getVariable ["CBE_Cortex_ThrowGeneration",-1]) != _throwGeneration) exitWith {};
                // No diagnostic/cancellation write may survive the original owner episode.
                if (!local _unit || {!local _group} || {group _unit != _group}
                    || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _ownerEpoch}
                    || {(_group getVariable ["CBE_OperationGeneration",0]) != _operationGeneration}) exitWith {};
                private _cancel = {
                    params [["_reason","OWNERSHIP_OR_SAFETY",[""]],["_details",[],[[]]]];
                    _unit setVariable ["CBE_Cortex_ThrowDecision",[time,_reason,_kind,_throwGeneration,_details]];
                    // A queued request is not a fired grenade. Retire only this danger
                    // carrier's unchanged reservation; never shorten a newer request's cooldown.
                    if (_kind == "SMOKE" && {count _context == 3} && {(_context select 0) == "DANGER"}
                        && {local _group} && {local _unit} && {group _unit == _group}
                        && {(_unit getVariable ["CBE_Cortex_ThrowGeneration",-1]) == _throwGeneration}
                        && {(_group getVariable ["CBE_OperationGeneration",0]) == _operationGeneration}
                        && {(_group getVariable ["CBE_AIPass_Epoch",0]) == _ownerEpoch}) then {
                        private _smokeLease=_group getVariable ["CBE_Danger_SmokeLease",[]];
                        if (_smokeLease isEqualType [] && {count _smokeLease == 3}
                            && {(_smokeLease select 0) isEqualTo (_context select 1)}
                            && {(_smokeLease select 1) isEqualTo _unit}
                            && {(_smokeLease select 2) isEqualType 0} && {finite (_smokeLease select 2)}
                            && {(_group getVariable ["CBE_Danger_SmokeAfter",-1]) isEqualTo ((_smokeLease select 2)+45)}) then {
                            _group setVariable ["CBE_Danger_SmokeLease",nil,true];
                            _group setVariable ["CBE_Danger_SmokeAfter",time+3];
                        };
                    };
                    if (_kind == "FRAG" && {_drillToken != ""}) then {
                        _unit setVariable ["CBE_Cortex_FragCancelled",_drillToken];
                    };
                };
                if (time > _expires) exitWith {["AIM_WINDOW_EXPIRED"] call _cancel};
                if !([_unit,_kind] call _fireAllowed) exitWith {["FIRE_POLICY_OR_FLIGHT_CHANGED"] call _cancel};
                if !([_unit,_context] call _contextMatches) exitWith {["DRILL_REPLACED"] call _cancel};
                if (!simulationEnabled _unit || {isObjectHidden _unit}
                    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}) exitWith {
                    ["ACTOR_UNAVAILABLE"] call _cancel;
                };
                if ((_group getVariable ["CBE_OperationGeneration",0]) != _operationGeneration
                    || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _ownerEpoch}
                    || {!local _group}
                    || {currentCommand _unit in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {
                    ["NEW_TASK",[_operationGeneration,_group getVariable ["CBE_OperationGeneration",0],
                        _ownerEpoch,_group getVariable ["CBE_AIPass_Epoch",0],currentCommand _unit]] call _cancel;
                };
                if (!([_unit] call CBE_fnc_CortexCombatEffective) || {!local _unit} || {isPlayer _unit} || {!isNull remoteControlled _unit} || {vehicle _unit != _unit} || {group _unit != _group}
                    || {[_unit] call CBE_fnc_CompatibilityExternalControl}
                    || {!([_group] call CBE_fnc_CortexIsEligible)}
                    || {(_group getVariable ["CBE_AIPass_ZeusHold",[]]) isNotEqualTo _hold}
                    || {!(_magazine in magazines _unit)}
                    || {(((_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]) getOrDefault ["token",""]) != _drillToken}) exitWith {[] call _cancel};
                // Reject at the callback scope: exitWith inside the context block only left
                // that block and allowed stale danger work to reach weapon release below.
                private _dangerInvalid=count _context == 3 && {(_context select 0) == "DANGER"} && {
                    !([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)
                        || {!([_group,"CBE_AIPass_DangerSmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
                        || {(_context select 1) != (_group getVariable ["CBE_Danger_Generation",-1])}
                        || {time >= (_context select 2)}
                        || {[_group] call CBE_fnc_CortexExternalTakeover}
                };
                if (_dangerInvalid) exitWith {[] call _cancel};
                if (count _context == 3 && {(_context select 0) == "DANGER"}) then {
                    // Selection and every queued retry share the same strict expiry contract.
                    // A malformed or newly acquired reservation cannot authorize a stale throw.
                    _dangerInvalid=[_unit] call CBE_fnc_CortexActorMoveReserved;
                };
                if (_dangerInvalid) exitWith {["ACTOR_RESERVED"] call _cancel};
                // A queued screen must still face the retained contact at release. Observation
                // may change during alignment; cancel rather than throw along an obsolete bearing.
                private _contactChanged=false;
                if (count _context == 3 && {(_context select 0) == "DANGER"}) then {
                    private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
                    private _contact=_state getOrDefault ["enemyPos",[]];
                    _contactChanged=!(_state getOrDefault ["contactKnowledge",false]) || {count _contact < 2};
                    if (!_contactChanged) then {
                        private _contactBearing=_unit getDir _contact;
                        private _throwBearing=_unit getDir _towards;
                        _contactChanged=abs (((_throwBearing-_contactBearing+540) % 360)-180) > 60
                            || {_unit distance2D _contact <= _unit distance2D _towards};
                    };
                };
                if (_contactChanged) exitWith {["CONTACT_CHANGED",[+_towards]] call _cancel};
                if (_kind == "FRAG" && {_drillToken != ""}
                    && {!([_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {[] call _cancel};
                private _alignAdmitted=false;
                isNil {
                    if ((_unit getVariable ["CBE_Cortex_ThrowGeneration",-1]) != _throwGeneration) exitWith {};
                    if (time > _expires || {!([_unit,_context] call _contextMatches)}) exitWith {};
                    // Carry one consumed request bit in this existing callback payload.
                    // Reissuing watch on every observation could fight a later native watch.
                    if (!_aimIssued) then {
                        _unit doWatch _towards;
                        _this set [16,true];
                    };
                    _alignAdmitted=true;
                };
                if (!_alignAdmitted) exitWith {
                    if ((_unit getVariable ["CBE_Cortex_ThrowGeneration",-1]) == _throwGeneration) then {
                        [["DRILL_REPLACED","AIM_WINDOW_EXPIRED"] select (time > _expires)] call _cancel;
                    };
                };
                // setDir changes the object transform without proving the prone throwing animation
                // has turned. Never force release into the actor's previous facing. A bounded
                // asynchronous aiming window leaves the manoeuvre element free to continue.
                private _bearing = _unit getDir _towards;
                private _bodyError = abs (((getDir _unit - _bearing + 540) % 360) - 180);
                // A lowered rifle can point across a standing actor's chest even when looking
                // towards contact. Its muzzle is not the grenade release orientation.
                private _aim = eyeDirection _unit;
                private _aimBearing = (_aim select 0) atan2 (_aim select 1);
                private _aimError = abs (((_aimBearing - _bearing + 540) % 360) - 180);
                if (_bodyError > 30 || {_aimError > 30}) exitWith {
                    if (time >= _expires) then {
                        ["ALIGNMENT_TIMEOUT",[_bodyError,_aimError,_muzzle,currentWeapon _unit,stance _unit]] call _cancel;
                    } else {
                        [_retry,+_this,0.25] call CBA_fnc_waitAndExecute;
                    };
                };
                private _unsafeRelease=false;
                private _safetyRadius=12;
                if (_kind == "FRAG") then {
                    private _distance=_unit distance2D _towards;
                    private _side=side _group;
                    private _releaseAmmo=getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
                    private _releaseConfig=configFile >> "CfgAmmo" >> _releaseAmmo;
                    private _blastRange=getNumber (_releaseConfig >> "indirectHitRange");
                    _safetyRadius=12 max (4*_blastRange);
                    _unsafeRelease=!isClass _releaseConfig || {!finite _blastRange} || {_blastRange < 0}
                        || {!finite _safetyRadius} || {_distance <= _safetyRadius} || {_distance < 8} || {_distance > 40}
                        || {(_towards nearEntities ["CAManBase",_safetyRadius]) findIf {
                            alive _x && {captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
                                || {_x getVariable ["ace_captives_isHandcuffed",false]}
                                || {side group _x == civilian} || {_side getFriend (side group _x) >= 0.6}}
                        } >= 0};
                };
                if (_unsafeRelease) exitWith {["UNSAFE_RELEASE",[_unit distance2D _towards,_safetyRadius]] call _cancel};
                // Safety geometry above stays scheduled. Bind listener setup and native
                // weapon release to the original caller context in this final transaction.
                isNil {
                if ((_unit getVariable ["CBE_Cortex_ThrowGeneration",-1]) != _throwGeneration) exitWith {};
                if (time > _expires) exitWith {["AIM_WINDOW_EXPIRED"] call _cancel};
                if !([_unit,_kind] call _fireAllowed) exitWith {["FIRE_POLICY_OR_FLIGHT_CHANGED"] call _cancel};
                if !([_unit,_context] call _contextMatches) exitWith {["DRILL_REPLACED"] call _cancel};
                _unit setVariable ["CBE_Cortex_ThrowDecision",[time,"ALIGNED",_kind,_throwGeneration,[_bodyError,_aimError,_muzzle]]];
                // Observe the native release once; never steer or replace the projectile.
                private _oldTrace=_unit getVariable ["CBE_Cortex_ThrowTraceHandler",-1];
                if (_oldTrace >= 0) then {_unit removeEventHandler ["FiredMan",_oldTrace]};
                _unit setVariable ["CBE_Cortex_ThrowOwner",[_group,_ownerEpoch,_operationGeneration,_throwGeneration,clientOwner]];
                _unit setVariable ["CBE_Cortex_ThrowTracePending",[_magazine,+_towards,_kind,_throwGeneration]];
                private _traceHandler=_unit addEventHandler ["FiredMan",{
                    params ["_actor","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
                    private _throwOwner=_actor getVariable ["CBE_Cortex_ThrowOwner",[]];
                    if (count _throwOwner != 5 || {!local _actor} || {!local group _actor}
                        || {(_throwOwner select 0) isNotEqualTo group _actor}
                        || {(_throwOwner select 1) isNotEqualTo ((group _actor) getVariable ["CBE_AIPass_Epoch",0])}
                        || {(_throwOwner select 2) isNotEqualTo ((group _actor) getVariable ["CBE_OperationGeneration",0])}
                        || {(_throwOwner select 3) isNotEqualTo (_actor getVariable ["CBE_Cortex_ThrowGeneration",-1])}
                        || {(_throwOwner select 4) isNotEqualTo clientOwner}) exitWith {};
                    private _pending=_actor getVariable ["CBE_Cortex_ThrowTracePending",[]];
                    if (_weapon == "Throw" && {count _pending == 4} && {_magazine == (_pending select 0)}
                        && {(_pending select 3) isEqualTo (_throwOwner select 3)}) then {
                        private _velocity=velocity _projectile;
                        private _bearing=_actor getDir (_pending select 1);
                        private _directionAvailable=!isNull _projectile
                            && {((_velocity select 0)^2+(_velocity select 1)^2) > 0.01};
                        private _launchBearing=if (_directionAvailable) then {(_velocity select 0) atan2 (_velocity select 1)} else {-1};
                        private _error=if (_directionAvailable) then {abs (((_launchBearing-_bearing+540) % 360)-180)} else {-1};
                        private _trace=[time,_pending select 2,_pending select 3,+(_pending select 1),_bearing,_launchBearing,_error,_velocity,_directionAvailable];
                        private _contactState=(group _actor) getVariable ["CBE_AIPass_State",createHashMap];
                        private _contact=+(_contactState getOrDefault ["enemyPos",[]]);
                        private _contactAvailable=_contactState getOrDefault ["contactKnowledge",false] && {count _contact >= 2};
                        private _contactBearing=if (_contactAvailable) then {_actor getDir _contact} else {-1};
                        private _contactError=if (_contactAvailable && {_directionAvailable}) then {
                            abs (((_launchBearing-_contactBearing+540) % 360)-180)
                        } else {-1};
                        _trace append [_contactAvailable,_contact,_contactBearing,_contactError];
                        private _releaseBody=getDir _actor;
                        private _releaseView=eyeDirection _actor;
                        private _releaseViewAvailable=(_releaseView select 0)^2+(_releaseView select 1)^2 > 0.01;
                        private _releaseViewBearing=if (_releaseViewAvailable) then {(_releaseView select 0) atan2 (_releaseView select 1)} else {-1};
                        private _releaseBodyError=abs (((_releaseBody-_bearing+540) % 360)-180);
                        private _releaseViewError=if (_releaseViewAvailable) then {abs (((_releaseViewBearing-_bearing+540) % 360)-180)} else {-1};
                        _trace append [[getPosATL _actor,_releaseBody,_releaseViewBearing,_releaseViewAvailable,
                            _releaseBodyError,_releaseViewError,stance _actor,animationState _actor]];
                        _actor setVariable ["CBE_Cortex_ThrowReleaseTrace",_trace];
                        diag_log format ["CBE GRENADE RELEASE TRACE: %1 %2",netId _actor,_trace];
                        _actor removeEventHandler ["FiredMan",_thisEventHandler];
                        _actor setVariable ["CBE_Cortex_ThrowTraceHandler",-1];
                        _actor setVariable ["CBE_Cortex_ThrowTracePending",nil];
                    };
                }];
                _unit setVariable ["CBE_Cortex_ThrowTraceHandler",_traceHandler];
                [{
                    params ["_actor","_handler","_group","_epoch","_generation","_issuer"];
                    if (!local _actor || {!local _group} || {group _actor != _group}
                        || {_issuer != clientOwner}
                        || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _epoch}
                        || {((_actor getVariable ["CBE_Cortex_ThrowTracePending",[]]) param [3,-1,[0]]) != _generation}) exitWith {};

                    if ((_actor getVariable ["CBE_Cortex_ThrowTraceHandler",-1]) == _handler) then {
                        _actor removeEventHandler ["FiredMan",_handler];
                        _actor setVariable ["CBE_Cortex_ThrowTraceHandler",-1];
                        _actor setVariable ["CBE_Cortex_ThrowTracePending",nil];
                    };
                },[_unit,_traceHandler,_group,_ownerEpoch,_throwGeneration,clientOwner],3] call CBA_fnc_waitAndExecute;
                if (_kind == "FRAG") then {
                    private _old = _unit getVariable ["CBE_Cortex_FragHandler",-1];
                    if (_old >= 0) then {_unit removeEventHandler ["FiredMan",_old]};
                    _unit setVariable ["CBE_Cortex_FragFlight",[_drillToken,objNull,false,_magazine,-1]];
                    _unit setVariable ["CBE_Cortex_FragFlightGeneration",_throwGeneration];
                    private _handler = _unit addEventHandler ["FiredMan",{
                        params ["_actor","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
                    private _throwOwner=_actor getVariable ["CBE_Cortex_ThrowOwner",[]];
                    if (count _throwOwner != 5 || {!local _actor} || {!local group _actor}
                        || {(_throwOwner select 0) isNotEqualTo group _actor}
                        || {(_throwOwner select 1) isNotEqualTo ((group _actor) getVariable ["CBE_AIPass_Epoch",0])}
                        || {(_throwOwner select 2) isNotEqualTo ((group _actor) getVariable ["CBE_OperationGeneration",0])}
                        || {(_throwOwner select 3) isNotEqualTo (_actor getVariable ["CBE_Cortex_ThrowGeneration",-1])}
                        || {(_throwOwner select 4) isNotEqualTo clientOwner}) exitWith {};
                        private _flight = _actor getVariable ["CBE_Cortex_FragFlight",[]];
                        if (_weapon == "Throw" && {count _flight == 5} && {_magazine == (_flight select 3)}
                            && {(_actor getVariable ["CBE_Cortex_FragFlightGeneration",-1]) isEqualTo (_throwOwner select 3)}) then {
                            _flight set [1,_projectile];
                            _flight set [2,true];
                            _flight set [4,time];
                            _actor removeEventHandler ["FiredMan",_thisEventHandler];
                            _actor setVariable ["CBE_Cortex_FragHandler",-1];
                        };
                    }];
                    _unit setVariable ["CBE_Cortex_FragHandler",_handler];
                    [{
                        params ["_actor","_handler","_group","_epoch","_generation","_issuer"];
                    if (!local _actor || {!local _group} || {group _actor != _group}
                        || {_issuer != clientOwner}
                        || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _epoch}
                        || {(_actor getVariable ["CBE_Cortex_FragFlightGeneration",-1]) != _generation}) exitWith {};

                        if ((_actor getVariable ["CBE_Cortex_FragHandler",-1]) == _handler) then {
                            _actor removeEventHandler ["FiredMan",_handler];
                            _actor setVariable ["CBE_Cortex_FragHandler",-1];
                        };
                    },[_unit,_handler,_group,_ownerEpoch,_throwGeneration,clientOwner],10] call CBA_fnc_waitAndExecute;
                _unit setVariable ["CBE_Cortex_ThrowDecision",[time,"RELEASE_REQUESTED",_kind,_throwGeneration,[_muzzle,currentWeapon _unit,stance _unit,+_towards,getDir _unit,eyeDirection _unit]]];
                    _unit forceWeaponFire [_muzzle,_muzzle];
                } else {
                _unit setVariable ["CBE_Cortex_ThrowDecision",[time,"RELEASE_REQUESTED",_kind,_throwGeneration,[_muzzle,currentWeapon _unit,stance _unit,+_towards,getDir _unit,eyeDirection _unit]]];
                    _unit forceWeaponFire [_muzzle,_muzzle];
                };
                };
            };
            [_release, [_unit,_muzzle,_magazine,group _unit,+(group _unit getVariable ["CBE_AIPass_ZeusHold",[]]),_kind,+_towards,_drillToken,+_context,time+1.5,_release,_throwGeneration,_operationGeneration,_ownerEpoch,_contextMatches,_fireAllowed]] call CBA_fnc_execNextFrame;
            _thrown = true;
            };
        };
    };
    if (_thrown) exitWith {};
} forEach (magazines _unit);
_thrown

