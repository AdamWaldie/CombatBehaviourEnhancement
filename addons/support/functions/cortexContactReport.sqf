/*
 * Author: WaldoTheWarfighter
 * Shares what a squad in contact can see with nearby friendly squads, by radio or by voice.
 *
 * Up to three recent believed positions are sent through the server to current receiving owners.
 * The recorded contact side lets an allied receiver reject reports about its own allies.
 * It is observation metadata, not a target object or permission to engage.
 * Report confidence comes from one native group-knowledge lookup per contact. Unit knowsAbout
 * reads shared group knowledge too; sampling squad members repeats the same query.
 * Receivers store an expiring area report for investigation, never reveal or track a target object.
 * Jamming restricts delivery to voice range. Sender/receiver feature gates are rechecked on delivery.
 * Locality/authority: sender owner reports; server validates and batches eight receivers per job step.
 * Repeat/JIP: sender cooldown and timestamps reject duplicate/stale work; reports expire and are not replayed.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: visible <ARRAY> - enemies from CBE_fnc_CortexKnowledge seen in the last 10 s
 *
 * Return Value:
 * Number - reports submitted; delivery is asynchronous
 *
 * Example:
 * [_group, _state, _visible] call CBE_fnc_CortexContactReport;
 * Result: eligible neighbouring owners receive an expiring area report.
 *
 * Current caller: CBE_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_visible", [], [[]]]];
_state set ["lastReport", time];
if (_visible isEqualTo []) exitWith {0};
if (!local _group || {!([_group,"CBE_AIPass_ContactReports_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {0};
if ((units _group) findIf {alive _x && {local _x} && {!isPlayer _x}} < 0) exitWith {0};
private _reports = (_visible select [0,3]) apply {
    private _target=_x select 0;
    private _confidence=_group knowsAbout _target;
    [+(_x select 1),1 min _confidence,serverTime - (_x select 2),side _target]
};
[_group,_reports,serverTime] remoteExecCall ["CBE_fnc_CortexReportServer",2];
count _reports
