class CfgPatches {
    class CBE_danger {
        name = "Combat Behaviour Enhancement (CBE) - Danger Brain";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main", "A3_Characters_F"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgVehicles {
    class CAManBase;
    class SoldierWB: CAManBase {
        fsmDanger = "z\cbe\addons\danger\danger.fsm";
    };
    class SoldierEB: CAManBase {
        fsmDanger = "z\cbe\addons\danger\danger.fsm";
    };
    class SoldierGB: CAManBase {
        fsmDanger = "z\cbe\addons\danger\danger.fsm";
    };
};
