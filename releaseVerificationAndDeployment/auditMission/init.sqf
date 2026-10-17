/*
 * Author: WaldoTheWarfighter
 * Purpose: Install disposable owner-side audit function definitions on server, clients and HCs.
 * Locality/authority: Every audit machine; installation itself starts no sampling, AI or handlers.
 * Repeat/JIP: Definitions install once per machine; late HCs receive them before fixture requests.
 * Arguments: None. Return: Nothing. Current caller: engine mission init.
 * Example: Run the checked-in staged audit mission; no production addon calls this script.
 */
if !(missionNamespace getVariable ["CBE_CortexQA_OwnerHelpersInstalled",false]) then {
    call compile preprocessFileLineNumbers "cortexQAPerformanceOwner.sqf";
    call compile preprocessFileLineNumbers "cortexQAIndoorActorOwner.sqf";
    private _installed=!isNil "CBE_CortexQA_PerformanceSampleOwner"
        && {!isNil "CBE_CortexQA_PerformanceDeleteGroup"} && {!isNil "CBE_CortexQA_PerformanceStartGroup"}
        && {!isNil "CBE_CortexQA_IndoorActorOwner"} && {!isNil "CBE_CortexQA_IndoorActorAckServer"};
    missionNamespace setVariable ["CBE_CortexQA_OwnerHelpersInstalled",_installed];
    if (!_installed) then {diag_log "CBE AUDIT ERROR: owner helper bootstrap incomplete"};
};
