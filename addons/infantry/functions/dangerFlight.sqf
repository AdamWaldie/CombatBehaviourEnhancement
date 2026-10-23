/*
 * Author: WaldoTheWarfighter
 * Purpose: Give an idle native-fleeing foot soldier a native rejoin or screened escape under the
 * existing engine danger FSM. This is separate from casualty investigation and group cover.
 * Locality/authority: Actor and group owner only. Existing native routes, reservations,
 * operations, medical work, Zeus and external controllers retain priority.
 * Empty release and non-fleeing start return before receipt validation or helper allocation.
 * Repeat/JIP: One local eight-field lease keeps its original deadline, at most twelve seconds.
 * Unchanged pre-request native planning may consume the original travel budget, never a new grace.
 * Pending cancellation retains immutable proof and is inspected by existing sparse DangerSetup.
 * No worker, waypoint, reveal, posture/speed reset or remote replay. One search per group
 * per two seconds and per actor per fifteen seconds bounds repeated failed observations.
 * Arguments: 0 mode STRING START or RELEASE; 1 actor OBJECT objNull;
 * 2 native danger record ARRAY [], used only for START.
 * Return: NUMBER remaining FSM wait on a screened START; zero for native rejoin, refusal or RELEASE.
 * Callers: DangerEngineAct, DangerEngineRelease and sparse DangerSetup cleanup. CanContinue reads only the local lease.
 * Example: ["START",soldier1,[2,[100,200,0],time+1,objNull]] call CBE_fnc_DangerFlight;
 * Quiet, distant group-only contact may hand an idle follower back to native formation once.
 * Recent personal contact, physical hazards and suppression never grant that rejoin path.
 * Native rejoin acquires no flight lease; its request is not acknowledgement or travel.
 * Arrival is a position result, not proof of effective cover or renewed morale. Failed exact
 * owned moves return to native formation; ambiguous/newer orders receive no cleanup command.
 */
params [["_mode","START",[""]],["_actor",objNull,[objNull]],["_record",[],[[]]]];
if (isNull _actor || {!(_mode in ["START","RELEASE"])}) exitWith {0};
if (!local _actor) exitWith {0};
private _lease=_actor getVariable ["CBE_Danger_FlightLease",[]];
// Most danger completions never owned a flight move. Keep that ordinary path minimal.
if (_lease isEqualTo [] && {_mode == "RELEASE" || {!fleeing _actor}}) exitWith {0};
private _group=group _actor;
private _validLease=_lease isEqualType [] && {count _lease == 8}
    && {(_lease select 0) isEqualType []} && {count (_lease select 0) == 3}
    && {(_lease select 0) findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} < 0}
    && {(_lease select 1) isEqualType 0} && {finite (_lease select 1)}
    && {(_lease select 2) isEqualType grpNull}
    && {(_lease select 3) isEqualType 0} && {finite (_lease select 3)}
    && {(_lease select 4) isEqualType 0} && {finite (_lease select 4)}
    && {(_lease select 5) isEqualType []}
    && {(_lease select 6) isEqualType 0} && {finite (_lease select 6)}
    && {(_lease select 6) <= time+1} && {(_lease select 1) >= (_lease select 6)}
    && {(_lease select 1) <= (_lease select 6)+12}
    && {(_lease select 7) isEqualType []} && {count (_lease select 7) == 3}
    && {((_lease select 7) select 0) isEqualTo ""}
    && {((_lease select 7) select 1) isEqualType []}
    && {((_lease select 7) select 2) isEqualType objNull};
if (_lease isNotEqualTo [] && {!_validLease}) exitWith {0};
private _available={
    local _actor && {!isNull _group} && {local _group} && {!isPlayer _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _actor}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
};
private _context={[_group getVariable ["CBE_AIPass_Epoch",0],
    _group getVariable ["CBE_OperationGeneration",0],[_group] call CBE_fnc_NativeOrderReceipt]};
if (_mode == "RELEASE") exitWith {
    if (local _actor && {_validLease}) then {
        _lease params ["_goal","_deadline","_oldGroup","_epoch","_generation","_route","_issued"];
        private _reservation=["DANGER_FLIGHT",_goal,_deadline];
        private _sameReservation=(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _reservation;
        private _arrived=(getPosASL _actor) vectorDistance (AGLToASL _goal) <= 2;
        private _before=_lease select 7;
        private _sameContext=_group == _oldGroup && {!isNull _group} && {local _group}
            && {[ _epoch,_generation,_route] isEqualTo (call _context)};
        private _pending=_sameReservation && {_sameContext}
            && {currentCommand _actor in [_before select 0,"MOVE"]}
            && {(expectedDestination _actor) isEqualTo (_before select 1)}
            && {formLeader _actor isEqualTo (_before select 2)}
            && {currentCommand _actor != "MOVE"
                || {((expectedDestination _actor) select 0) vectorDistance _goal > 0.25}};
        // The engine may still consume the original doMove. Empty metadata is not cancellation.
        if (_pending) exitWith {
            _actor setVariable ["CBE_Danger_FlightResult",[
                ["CANCEL_PENDING","UNRESOLVED_DEADLINE"] select (time >= _deadline+30),
                time,+_goal,_issued,_deadline]];
        };
        if (!_arrived && {_sameReservation} && {_sameContext} && {time >= _deadline+30}
            && {currentCommand _actor == "MOVE"}
            && {((expectedDestination _actor) select 0) vectorDistance _goal <= 0.25}) exitWith {
            // Acknowledgement after the original cleanup window grants no late follow command.
            _actor setVariable ["CBE_Danger_FlightResult",["UNRESOLVED_DEADLINE",time,+_goal,_issued,_deadline]];
        };
        private _owns=_sameReservation && {_group == _oldGroup} && {call _available}
            && {[ _epoch,_generation,_route] isEqualTo (call _context)}
            && {currentCommand _actor == "MOVE"}
            && {((expectedDestination _actor) select 0) vectorDistance _goal <= 0.25}
            && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0};
        private _reason=if (_arrived) then {"AT_COVER_POSITION"} else {"OWNERSHIP_CHANGED"};
        if (!_arrived && {_owns} && {!isNull leader _group}
            && {local leader _group} && {[leader _group] call CBE_fnc_CortexCombatEffective}) then {
            _actor doFollow leader _group;
            _reason="NATIVE_RETURN_REQUESTED";
        };
        if (_sameReservation) then {_actor setVariable ["CBE_Cortex_ActorMove",nil]};
        _actor setVariable ["CBE_Danger_FlightLease",nil];
        _actor setVariable ["CBE_Danger_FlightResult",[_reason,time,+_goal,_issued,_deadline]];
    };
    0
};
if (!local _actor || {!local _group}) exitWith {0};
// An unrelated callback cannot extend a running escape or borrow its restoration authority.
if (_lease isNotEqualTo []) exitWith {
    if (_validLease && {(_lease select 2) == _group}
        && {[ _lease select 3,_lease select 4,_lease select 5] isEqualTo (call _context)}
        && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo
            ["DANGER_FLIGHT",_lease select 0,_lease select 1]}) then {
        ((_lease select 1)-time) max 0
    } else {0}
};
if (!fleeing _actor || {!call _available}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible)}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}
    || {currentCommand _actor != ""} || {abs speed _actor >= 0.5}
    || {getUnitState _actor in ["INIT","PLANNING","REPLAN"]}
    || {time < (_actor getVariable ["CBE_Danger_FlightAfter",-1])}
    || {time < (_group getVariable ["CBE_Danger_FlightSearchAfter",-1])}) exitWith {0};
private _threat=_record param [1,[],[[]]];
private _expires=_record param [2,-1,[0]];
private _cause=_record param [0,-1,[0]];
if (!(_cause in [0,1,2,3,4,8,9]) || {!finite _expires} || {_expires <= time}
    || {count _threat != 3} || {_threat findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}) exitWith {0};
private _source=_record param [3,objNull,[objNull]];
private _nativeKnowledge=if (isNull _source) then {[]} else {_actor targetKnowledge _source};
if (_nativeKnowledge param [7,false,[true]]) exitWith {0};
if (_cause in [0,3,8] && {isNull _source || {!alive _source} || {captive _source}
    || {_source isKindOf "Logic"} || {_source isKindOf "HeadlessClient_F"}
    || {_source getVariable ["ace_captives_isSurrendering",false]}
    || {_source getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _source) >= 0.6}
    || {_actor knowsAbout _source < 1}}) exitWith {0};
private _origin=getPosATL _actor;
if (_origin distance2D _threat < 3) exitWith {0};
private _entry=call _context;
_actor setVariable ["CBE_Danger_FlightAfter",time+15];
_group setVariable ["CBE_Danger_FlightSearchAfter",time+2];
// A follower with only distant group belief can rejoin without searching terrain or
// taking a second movement lease. Current native personal observation vetoes that inference;
// a quiet group report is not equivalent to the actor having visual contact itself.
private _personalAt=(_nativeKnowledge param [2,-1,[0]]) max (_nativeKnowledge param [3,-1,[0]]);
private _personalPressure=(_nativeKnowledge param [1,false,[true]])
    && {_personalAt >= 0} && {time <= _personalAt+5};
private _leader=leader _group;
private _physicalUntil=_actor getVariable ["CBE_Danger_PhysicalUntil",-1];
private _quietRejoin=_cause in [0,3,8] && {_origin distance2D _threat > 75}
    && {!_personalPressure} && {getSuppression _actor < 0.2}
    && {_physicalUntil isEqualType 0} && {finite _physicalUntil} && {time > _physicalUntil}
    && {!isNull _leader} && {_leader != _actor} && {local _leader}
    && {[_leader] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _leader}
    && {simulationEnabled _leader} && {!isObjectHidden _leader}
    && {_actor distance2D _leader > 8};
if (_quietRejoin) exitWith {
    if (call _available && {fleeing _actor} && {_entry isEqualTo (call _context)}
        && {currentCommand _actor == ""} && {abs speed _actor < 0.5}
        && {!(getUnitState _actor in ["INIT","PLANNING","REPLAN"])}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}) then {
        _actor doFollow _leader;
        _actor setVariable ["CBE_Danger_FlightResult",["NATIVE_REJOIN_REQUESTED",time,getPosATL _leader,time,time]];
    };
    0
};
private _rayStart=(AGLToASL _threat) vectorAdd [0,0,1.6];
// Already screened actors keep their native position. Never force them out into another route.
if ([_rayStart,(getPosASL _actor) vectorAdd [0,0,1],_actor,"COVER"]
    call CBE_fnc_CortexCoverScreened) exitWith {0};
([_origin,_threat,18,[],_group,"COVER",_actor] call CBE_fnc_CortexFindCover) params ["_goal","_found"];
// Exterior cover remains preferred. A roofed native node is a candidate, not access proof.
if (!_found && {[_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled}) then {
    private _refugeHouses=nearestObjects [_origin,["House"],18,true];
    {
        private _refugeHouse=_x;
        if (alive _refugeHouse) then {
            private _refugeFrame=[getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse];
            private _refugeNode=[_actor,_refugeHouse,_origin,[]] call CBE_fnc_IndoorActorNodeSelect;
            if (count _refugeNode == 3 && {_origin vectorDistance _refugeNode >= 0.6}
                && {_origin vectorDistance _refugeNode <= 18}
                && {[_rayStart,(AGLToASL _refugeNode) vectorAdd [0,0,1],_actor,"COVER"]
                    call CBE_fnc_CortexCoverScreened}
                && {alive _refugeHouse}
                && {_refugeFrame isEqualTo [getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse]}) then {
                _goal=+_refugeNode;
                _found=true;
            };
        };
        if (_found) exitWith {};
    } forEach (_refugeHouses select [0,2]);
};
if (!_found || {count _goal != 3} || {_origin vectorDistance _goal < 0.6}
    || {_origin vectorDistance _goal > 18}
    || {!([_rayStart,(AGLToASL _goal) vectorAdd [0,0,1],_actor,"COVER"]
        call CBE_fnc_CortexCoverScreened)}) exitWith {0};
// Selection is read-only. Recheck the actual movement owner before issuing the sole command.
if (!call _available || {!fleeing _actor} || {_entry isNotEqualTo (call _context)}
    || {currentCommand _actor != ""} || {abs speed _actor >= 0.5}
    || {getUnitState _actor in ["INIT","PLANNING","REPLAN"]}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}) exitWith {0};
private _before=[currentCommand _actor,expectedDestination _actor,formLeader _actor];
private _deadline=time+((2+(_origin vectorDistance _goal)/2) max 4 min 12);
_actor doMove _goal;
_actor setVariable ["CBE_Cortex_ActorMove",["DANGER_FLIGHT",+_goal,_deadline]];
_actor setVariable ["CBE_Danger_FlightLease",[+_goal,_deadline,_group,_entry select 0,_entry select 1,_entry select 2,time,_before]];
_actor setVariable ["CBE_Danger_FlightResult",["MOVE_REQUESTED",time,+_goal,time,_deadline]];
_deadline-time
