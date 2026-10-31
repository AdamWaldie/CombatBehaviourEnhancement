/*
 * Author: WaldoTheWarfighter
 * Accepts a reservation only after checking local eligibility, actual capability and existing orders.
 * Locality/authority: server owns reservations; current group owners validate and execute orders.
 * Repeat/JIP: unique tokens, shared deadlines and owner acknowledgements retire stale assignments.
 * Owner-change redelivery waits for canonical Locality adoption; it cannot recreate a parent.
 * Arguments: 0: helper <GROUP>, grpNull; 1: server lease <ARRAY>, [];
 * 2: ownership-change redelivery <BOOL>, false, set only by the server SupportStep.
 * Return Value: Nothing.
 * Current callers: SupportStep.
 * Example: [_group, _lease] remoteExecCall ["CBE_fnc_CortexSupportLocal", groupOwner _group];
 */
params [["_group",grpNull,[grpNull]],["_lease",[],[[]]],["_ownerChange",false,[true]]];
if (remoteExecutedOwner != 2 || {isNull _group} || {!local _group} || {count _lease != 7}) exitWith {};
[CBE_fnc_CortexSupportApply,createHashMapFromArray [["group",_group],["lease",_lease],
    ["waitUntil",serverTime+5],["ownerChange",_ownerChange],["adopt",_ownerChange]],0] call CBE_fnc_CortexQueueJob;
