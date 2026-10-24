// Author: WaldoTheWarfighter
// Restart-required native AI launcher policy. Player dispersion, recoil, sounds and
// projectile physics/damage remain unchanged. Global to affected config classes.
class CfgPatches {
    class CBE_policy_launchers {
        name = "Combat Behaviour Enhancement (CBE) - Native Launcher Policy";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Weapons_F", "A3_Weapons_F_Exp", "A3_Weapons_F_Tank", "CBE_infantry"};
        units[] = {};
        weapons[] = {};
    };
};
class Mode_SemiAuto;
class CfgWeapons {
    class Launcher;
    class Launcher_Base_F: Launcher {};
    class launch_RPG7_F: Launcher_Base_F {
        class Single: Mode_SemiAuto {
            aiDispersionCoefX = 1.8;
            aiDispersionCoefY = 2.4;
            aiRateOfFire = 5;
            aiRateOfFireDispersion = 5;
            aiRateOfFireDistance = 450;
            maxRange = 450;
            maxRangeProbab = 1.8;
            midRange = 200;
            midRangeProbab = 2.5;
            minRange = 5;
            minRangeProbab = 0.6;
        };
    };
    class launch_RPG32_F: Launcher_Base_F {
        class Single: Mode_SemiAuto {
            aiDispersionCoefX = 1.7;
            aiDispersionCoefY = 2.2;
            aiRateOfFire = 7;
            aiRateOfFireDispersion = 3;
            aiRateOfFireDistance = 400;
            maxRange = 600;
            maxRangeProbab = 1.5;
            midRange = 40;
            midRangeProbab = 1.1;
            minRange = 10;
            minRangeProbab = 0.2;
        };
    };
};
class CfgAmmo {
    class RocketBase;
    class R_PG7_F: RocketBase {
        aiAmmoUsageFlags = 960;
        allowAgainstInfantry = 1;
    };
    class M_SPG9_HEAT: RocketBase {
        aiAmmoUsageFlags = 704;
        allowAgainstInfantry = 1;
    };
    class R_PG32V_F: RocketBase {
        aiAmmoUsageFlags = 960;
        allowAgainstInfantry = 1;
    };
    class R_MRAAWS_HEAT_F: RocketBase {
        aiAmmoUsageFlags = 704;
        allowAgainstInfantry = 1;
    };
};
