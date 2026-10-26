import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StandaloneExtractionContracts(unittest.TestCase):
    def test_registered_sqf_files_exist_and_document_authority(self):
        functions = (ROOT / "addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        paths = re.findall(r'file\s*=\s*"([^"]+\.sqf)"', functions)
        self.assertGreater(len(paths), 100)
        for relative in paths:
            relative = relative.replace("\\", "/")
            relative = relative.removeprefix("/z/cbe/")
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            header = path.read_text(encoding="utf-8")[:8000]
            self.assertIn("Author: WaldoTheWarfighter", header, relative)
            self.assertRegex(header, r"(?i)locality|authority", relative)
            self.assertRegex(header, r"(?i)repeat|JIP", relative)

    def test_cba_xeh_replaces_mission_bootstrap(self):
        config = (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8")
        pre = (ROOT / "addons/main/XEH_preInit.sqf").read_text(encoding="utf-8")
        post = (ROOT / "addons/main/XEH_postInit.sqf").read_text(encoding="utf-8")
        self.assertIn('requiredAddons[] = {"cba_main", "cba_xeh", "A3_Modules_F", "CBE_core", "CBE_danger", "CBE_infantry", "CBE_vehicles", "CBE_aircraft", "CBE_support", "CBE_compatibility"}', config)
        self.assertIn("Extended_PreInit_EventHandlers", config)
        self.assertIn("Extended_PostInit_EventHandlers", config)
        self.assertIn("addons\\main\\settings\\aiConfig.sqf", pre)
        self.assertIn('CBE_AITweaks_SettingsReady", true', pre)
        self.assertIn("CBE_fnc_CortexInit", post)
        self.assertIn("CBE_fnc_CortexZeusWatchLocal", post)

    def test_wait_systems_are_outside_the_standalone_tree(self):
        forbidden = ("DynamicAA", "DynamicAO", "Economy", "TransportServices", "Paradrop")
        all_paths = {path.as_posix() for path in ROOT.rglob("*")}
        for subsystem in forbidden:
            self.assertFalse(any(f"/{subsystem}/" in path for path in all_paths), subsystem)

    def test_production_has_no_wait_private_system_coupling(self):
        production = "\n".join(
            path.read_text(encoding="utf-8-sig")
            for path in (ROOT / "addons").rglob("*")
            if path.suffix in {".sqf", ".hpp"}
        )
        for private_name in (
            "CBE_DynamicAA_",
            "CBE_DynamicAO_",
            "CBE_TransportService_",
            "CBE_Paradrop_",
            "CBE_Gunship_",
            "CBE_ServerOwnedFeature",
        ):
            self.assertNotIn(private_name, production)
        self.assertIn("Waldo_AI_ExternalControl", production)
        self.assertIn("Waldo_AI_PrecisionExclude", production)

    def test_packaging_files_define_one_namespaced_addon(self):
        self.assertTrue((ROOT / ".hemtt/project.toml").is_file())
        self.assertEqual(
            (ROOT / "addons/main/$PBOPREFIX$").read_text(encoding="utf-8").strip(),
            "z\\cbe\\addons\\main",
        )
        config = (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8")
        self.assertIn("class CBE_AI_Tweaks_Main", config)
        self.assertNotIn("zen_main", config)

    def test_cba_settings_and_compatibility_are_native_addon_services(self):
        pre = (ROOT / "addons/main/XEH_preInit.sqf").read_text(encoding="utf-8")
        functions = (ROOT / "addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        settings = (ROOT / "addons/core/functions/aiTweaksRegisterSettings.sqf").read_text(encoding="utf-8")
        compat = (ROOT / "addons/compatibility/functions/aiTweaksDetectCompatibility.sqf").read_text(encoding="utf-8")
        self.assertIn("CBE_fnc_AITweaksRegisterSettings", pre)
        self.assertIn("CBE_fnc_AITweaksDetectCompatibility", pre)
        self.assertIn("AITweaksRegisterSettings", functions)
        self.assertIn("CBA_fnc_addSetting", settings)
        self.assertIn("_this] call CBE_fnc_AITweaksSettingChanged", settings)
        self.assertNotIn("params ['_value']", settings)
        self.assertNotIn('"zen_main"', (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8"))
        for capability in ("meleeBackend", "specialistBackend"):
            self.assertIn(f'"{capability}"', compat)
        for capability in ("alternativeBackend", "drivingBackend", "navalBackend", "medicalBackend", "civilianBackend", "dangerBackend"):
            self.assertNotIn(f'"{capability}"', compat)

    def test_local_lifecycle_anchor_is_not_a_communication_proxy(self):
        functions = (ROOT / "addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        anchor = (ROOT / "addons/infantry/functions/cortexGroupAnchor.sqf").read_text(encoding="utf-8")
        transmitter = (ROOT / "addons/infantry/functions/cortexGroupTransmitter.sqf").read_text(encoding="utf-8")
        self.assertIn('class CortexGroupAnchor', functions)
        self.assertIn('CortexCombatEffective', anchor)
        self.assertIn('local _actor', anchor)
        self.assertIn('(units _group) select [0,12]', anchor)
        self.assertIn('isNull remoteControlled _actor', anchor)
        self.assertIn('CortexExternalOwner', anchor)
        self.assertNotIn('CortexCanTransmit', anchor)
        self.assertIn('CortexCanTransmit', transmitter)

    def test_native_curator_commands_do_not_require_optional_dialogs(self):
        config = (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8")
        native = (ROOT / "addons/vehicles/functions/moduleConvoy.sqf").read_text(encoding="utf-8")
        watcher = (ROOT / "addons/core/functions/cortexZeusWatchLocal.sqf").read_text(encoding="utf-8")
        dialog = (ROOT / "addons/vehicles/functions/zenConvoyModule.sqf").read_text(encoding="utf-8")
        for name in ("CBE_ModuleConvoyStart", "CBE_ModuleConvoyHold", "CBE_ModuleConvoyRelease"):
            self.assertIn(name, config)
        self.assertIn("Extended_DisplayLoad_EventHandlers", config)
        self.assertIn("RscDisplayCurator", config)
        self.assertIn('CBE_AIPass_ZeusInstallLocal', watcher)
        self.assertIn('attachedTo _logic', native)
        self.assertIn('!local _logic', native)
        self.assertIn('CBE_processed', native)
        self.assertNotIn('nearest', native.lower().replace('no nearby vehicle', ''))
        self.assertNotIn('zen_dialog_fnc_create', native)
        self.assertIn('isNil "zen_dialog_fnc_create"', dialog)
        launcher = (ROOT / "releaseVerificationAndDeployment/launch_mod_audit.ps1").read_text(encoding="utf-8")
        self.assertIn('if ($WithZen)', launcher)
        airborne=(ROOT/'addons/aircraft/functions/moduleAirborne.sqf').read_text(encoding='utf-8')
        owner=(ROOT/'addons/infantry/functions/cortexOrderLocal.sqf').read_text(encoding='utf-8')
        dispatch=(ROOT/'addons/infantry/functions/cortexOrderDispatch.sqf').read_text(encoding='utf-8')
        self.assertIn('class CBE_ModuleAirborne: Module_F',config)
        self.assertIn('function = "CBE_fnc_ModuleAirborne";',config)
        self.assertIn('attachedTo _logic',airborne)
        self.assertIn('!local _logic',airborne)
        self.assertIn('CBE_processed',airborne)
        self.assertNotIn('zen_',airborne)
        self.assertNotIn('nearest',airborne.lower())
        self.assertIn('["passenger",_passenger],["aircraft",_aircraft]',airborne)
        self.assertIn('CBE_fnc_CortexOrderDispatch',airborne)
        self.assertNotIn('CBE_fnc_CortexAirborneDrop',airborne)
        self.assertIn('"passenger" in _settings || {"aircraft" in _settings}',dispatch)
        case=owner.split('case "AIRBORNE": {',1)[1].split('default {false}',1)[0]
        for check in ('objectParent _passenger == _aircraft','CortexCombatEffective',
                      'fullCrew [_aircraft,"cargo"]','vehicle _x != _aircraft',
                      'if (!_witnessCurrent) exitWith {false};','CortexAirborneDrop'):
            self.assertIn(check,case)
        self.assertLess(case.index('if (!_witnessCurrent)'),case.index('CortexAirborneDrop'))


    def test_curator_waypoint_edit_uses_native_group_and_id_payload(self):
        watcher = (ROOT / "addons/core/functions/cortexZeusWatchLocal.sqf").read_text(encoding="utf-8")
        native = watcher.split('params ["", "_group", "_waypointID"];', 1)[1]
        group_events, array_events = native.split('} forEach ["CuratorWaypointPlaced", "CuratorWaypointEdited"];', 1)
        self.assertIn('[_group,true,_waypointID] call CBE_fnc_CortexZeusMark', group_events)
        self.assertIn('params ["", "_waypoint"];', array_events)
        self.assertIn('["CuratorWaypointDeleted", "CuratorWaypointDoubleClicked"]', array_events)
        self.assertNotIn('"CuratorWaypointEdited"', array_events)
        self.assertNotIn('CuratorGroupSelectionChanged', watcher)
        self.assertNotIn('CuratorObjectSelectionChanged', watcher)

    def test_temporary_group_routes_preserve_non_geometric_authored_edits(self):
        move=(ROOT/"addons/infantry/functions/cortexGroupMove.sqf").read_text(encoding="utf-8")
        clear=(ROOT/"addons/infantry/functions/cortexGroupMoveClear.sqf").read_text(encoding="utf-8")
        self.assertIn('["nativePolicy",[_committedRow select 3,_committedRow select [6]]]',move)
        self.assertIn('private _scheduledPolicy=canSuspend;',move)
        self.assertIn('if (_scheduledPolicy) then {call _readPolicy} else {_observedPolicy}',move)
        self.assertLess(move.index('private _scheduledPolicy=canSuspend;'),move.index('private _policyUnchanged='))
        self.assertGreaterEqual(move.count('call _policyUnchanged'),2)
        self.assertIn('_priorPolicy isEqualTo [] || {_policy isNotEqualTo _priorPolicy}',clear)
        self.assertLess(clear.index('_policy isNotEqualTo _priorPolicy'),clear.index('deleteWaypoint _ownedWaypoint'))
        self.assertIn('_ownedWaypoint setWaypointDescription ""',clear)
        receipt=(ROOT/"addons/core/functions/authoredRouteReceipt.sqf").read_text(encoding="utf-8")
        for field in ('waypointStatements','waypointTimeout','waypointSpeed','waypointBehaviour',
                      'waypointCombatMode','waypointFormation','waypointScript','waypointAttachedVehicle',
                      'waypointAttachedObject','synchronizedTriggers','synchronizedWaypoints',
                      'waypointHousePosition','waypointLoiterType','waypointForceBehaviour'):
            self.assertIn(field,receipt)

    def test_group_route_cleanup_is_atomic_and_intent_scoped(self):
        clear=(ROOT/"addons/infantry/functions/cortexGroupMoveClear.sqf").read_text(encoding="utf-8")
        atomic=clear.split('isNil {',1)[1].rsplit('};',1)[0]
        for marker in ('if (!local _group) exitWith {};','private _intent =',
                       'operationGeneration",-1]) != _operationGeneration',
                       'CBE_Cortex_GroupMoveIntent", nil, true','deleteWaypoint _ownedWaypoint'):
            self.assertIn(marker,atomic)
        self.assertEqual(clear.count('deleteWaypoint'),2)  # header command documentation + exact deletion
        self.assertNotIn('for "_index" from',clear)
        self.assertNotIn('uiSleep',atomic)
        self.assertNotIn('remoteExec',atomic)

    def test_product_boundary_is_documented(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for name in ("Dynamic AA", "Dynamic AO", "CBA_A3", "Zeus", "JIP"):
            self.assertIn(name, readme)


if __name__ == "__main__":
    unittest.main()
