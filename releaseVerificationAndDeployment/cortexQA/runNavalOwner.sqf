/*
 * Author: WaldoTheWarfighter
 * Purpose: Install read-only owner-side naval audit sampling and authenticated server ACK.
 * Locality/authority: Installed on every disposable audit machine. Only a server request may
 * read a local boat. Only that boat's requested real owner may acknowledge the current nonce.
 * Repeat/JIP: No handlers, timers or production mutation. Server replaces one pending nonce;
 * stale replies cannot satisfy a later request. No JIP replay.
 * Arguments: SampleOwner: nonce STRING,boat OBJECT. AckServer: nonce STRING,boat OBJECT,data ARRAY.
 * Return: Nothing. Current callers: runNaval.sqf via remoteExecCall, audit init.sqf installation.
 * Example: ["NAVAL:1",_boat] remoteExecCall ["CBE_CortexQA_NavalSampleOwner",owner _boat];
 */
CBE_CortexQA_NavalSampleOwner={
    params [["_nonce","",[""]],["_boat",objNull,[objNull]]];
    if (remoteExecutedOwner != 2 || {_nonce == ""} || {count _nonce > 80}
        || {isNull _boat} || {!local _boat} || {!(_boat isKindOf "Ship")}) exitWith {};
    [_nonce,_boat,[clientOwner,getForcedSpeed _boat,
        +(_boat getVariable ["CBE_Cortex_NavalForcedSpeed",[]]),
        +(_boat getVariable ["CBE_Cortex_NavalPlan",[]])]]
        remoteExecCall ["CBE_CortexQA_NavalAckServer",2];
};
CBE_CortexQA_NavalAckServer={
    params [["_nonce","",[""]],["_boat",objNull,[objNull]],["_data",[],[[]]]];
    if (!isServer || {isNull _boat} || {count _data != 4}) exitWith {};
    private _pending=missionNamespace getVariable ["CBE_CortexQA_NavalPending",[]];
    if (count _pending != 3 || {(_pending select 0) != _nonce}
        || {(_pending select 1) != remoteExecutedOwner} || {(_pending select 2) != _boat}
        || {owner _boat != remoteExecutedOwner} || {(_data select 0) != remoteExecutedOwner}) exitWith {};
    missionNamespace setVariable ["CBE_CortexQA_NavalSample",[_nonce,_data]];
    missionNamespace setVariable ["CBE_CortexQA_NavalPending",nil];
};
