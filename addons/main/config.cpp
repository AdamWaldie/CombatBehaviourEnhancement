#include "script_component.hpp"

class CfgPatches {
    class CBE_AI_Tweaks_Main {
        name = "Combat Behaviour Enhancement (CBE)";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main", "cba_xeh", "A3_Modules_F", "CBE_core", "CBE_danger", "CBE_infantry", "CBE_vehicles", "CBE_aircraft", "CBE_support", "CBE_compatibility"};
        units[] = {"CBE_ModuleConvoyStart", "CBE_ModuleConvoyHold", "CBE_ModuleConvoyRelease", "CBE_ModuleGarrison", "CBE_ModuleDefend", "CBE_ModuleDrivingCorridor", "CBE_ModuleDrivingCorridorMission", "CBE_DrivingCorridorArea"};
        weapons[] = {};
        version = "0.1.0";
        versionStr = "0.1.0";
        versionAr[] = {0, 1, 0};
    };
};

class Extended_PreInit_EventHandlers {
    class CBE_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\cbe\addons\main\XEH_preInit.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class CBE_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\cbe\addons\main\XEH_postInit.sqf'";
    };
};

#include "CfgFunctions.hpp"

// Native curator orders are available without an optional dialog provider.
class CfgFactionClasses {
    class CBE_CuratorOrders {
        displayName = "Combat Behaviour Enhancement (CBE)";
        priority = 2;
        side = 7;
    };
};
class CfgVehicles {
    class Logic;
    class CBE_DrivingCorridorArea: Logic {
        scope = 1;
        scopeCurator = 0;
        displayName = "Navigation corridor area";
        category = "CBE_CuratorOrders";
    };
    class Module_F: Logic {
        class AttributesBase {
            class Combo;
            class ModuleDescription;
        };
        class ModuleDescription;
    };
    class CBE_ModuleDrivingCorridor: Module_F {
        scope = 1;
        scopeCurator = 2;
        displayName = "Navigation corridor";
        category = "CBE_CuratorOrders";
        function = "CBE_fnc_ModuleDrivingCorridor";
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 1;
        curatorCanAttach = 1;
    };
    class CBE_ModuleDrivingCorridorMission: CBE_ModuleDrivingCorridor {
        scope = 2;
        scopeCurator = 0;
        displayName = "Navigation corridor (mission)";
        function = "CBE_fnc_ModuleDrivingCorridorMission";
        isGlobal = 0;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;
        curatorCanAttach = 0;
        canSetArea = 1;
        canSetAreaShape = 0;
        canSetAreaHeight = 0;
        class AttributeValues {
            size3[] = {5, 25, -1};
            isRectangle = 1;
        };
        class Attributes: AttributesBase {
            class Speed: Combo {
                property = "CBE_DrivingCorridor_EdenSpeed";
                displayName = "Task speed (km/h)";
                tooltip = "Upper speed inside this corridor. Existing traffic and obstacle limits still apply.";
                typeName = "NUMBER";
                defaultValue = "15";
                expression = "if (isServer) then {_this setVariable ['CBE_DrivingCorridor_EdenSpeed',_value]};";
                class Values {
                    class Walking {name = "5 km/h"; value = 5;};
                    class Slow {name = "10 km/h"; value = 10;};
                    class Normal {name = "15 km/h"; value = 15;};
                    class Moderate {name = "20 km/h"; value = 20;};
                    class Fast {name = "30 km/h"; value = 30;};
                };
            };
            class ModuleDescription: ModuleDescription {};
        };
        class ModuleDescription: ModuleDescription {
            description[] = {
                "Define a rectangular route through a dry, supported bridge or narrow passage. The arrow points along the corridor.",
                "Half-width must be 2-20 m; half-length must be 5-45 m. Preserve the bridge deck height when placing the module.",
                "Existing vehicle routes must cross opposite ends. Registration does not prove access or permit driving through obstructions or water.",
                "Without a synchronized trigger the task is active at mission start. Trigger deactivation removes it; repeat activation re-registers it."
            };
            sync[] = {};
        };
    };
    class CBE_ModuleGarrison: Module_F {
        scope = 1;
        scopeCurator = 2;
        displayName = "Garrison area";
        category = "CBE_CuratorOrders";
        function = "CBE_fnc_ModuleGarrison";
        CBE_operation = "GARRISON";
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 1;
        curatorCanAttach = 1;
    };
    class CBE_ModuleDefend: CBE_ModuleGarrison {
        displayName = "Defend area";
        CBE_operation = "DEFEND";
    };
    class CBE_ModuleConvoyStart: Module_F {
        scope = 1;
        scopeCurator = 2;
        displayName = "Convoy: start / resume";
        category = "CBE_CuratorOrders";
        function = "CBE_fnc_ModuleConvoy";
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 1;
        curatorCanAttach = 1;
        CBE_operation = "START";
    };
    class CBE_ModuleConvoyHold: CBE_ModuleConvoyStart {
        displayName = "Convoy: hold and unload passengers";
        CBE_operation = "STOP";
    };
    class CBE_ModuleConvoyRelease: CBE_ModuleConvoyStart {
        displayName = "Convoy: release control";
        CBE_operation = "RELEASE";
    };
};
class Extended_DisplayLoad_EventHandlers {
    class RscDisplayCurator {
        CBE_AI_Tweaks = "call (missionNamespace getVariable ['CBE_AIPass_ZeusInstallLocal', {}])";
    };
};
