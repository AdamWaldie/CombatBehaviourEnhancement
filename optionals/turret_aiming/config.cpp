// Author: WaldoTheWarfighter
// Optional restart-required native AI aiming and dispersion policy.
// Player dispersion, projectile, recoil, ammunition and native burst lengths stay unchanged.
// Native AI bursts remain terminable when their target dies or leaves sight.
class CfgPatches {
    class CBE_policy_turret_aiming {
        name = "Combat Behaviour Enhancement (CBE) - Optional AI Turret Aiming";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Characters_F", "A3_Weapons_F", "A3_Weapons_F_Exp", "A3_Weapons_F_Tank", "CBE_vehicles"};
        units[] = {};
        weapons[] = {};
    };
};
class CfgBrains {
    class DefaultSoldierBrain {
        class Components {
            class AIBrainAimingErrorComponent {
                maxAngularErrorTurrets = 0.12;
            };
        };
    };
};
// Reopen native classes with their original parents. Only AI-specific coefficients
// and termination permission are patched; inherited fire modes keep their cadence.
class CfgWeapons {
    class MGun;
    class LMG_RCWS: MGun {
        aiDispersionCoefX = 5;
        aiDispersionCoefY = 4;
        class manual: MGun {};
        class close: manual {
            aiDispersionCoefX = 6;
            aiDispersionCoefY = 7;
            aiBurstTerminable = 1;
        };
        class short: close { aiBurstTerminable = 1; };
        class medium: close { aiBurstTerminable = 1; };
        class far: close { aiBurstTerminable = 1; };
    };
    class HMG_127: LMG_RCWS {
        class manual: MGun {};
        class close: manual {
            aiDispersionCoefX = 6;
            aiDispersionCoefY = 7;
            aiBurstTerminable = 1;
        };
        class short: close { aiBurstTerminable = 1; };
        class medium: close { aiBurstTerminable = 1; };
        class far: close { aiBurstTerminable = 1; };
    };
    class LMG_coax: LMG_RCWS {
        class manual: MGun {};
        class close: manual {
            aiDispersionCoefX = 6;
            aiDispersionCoefY = 7;
            aiBurstTerminable = 1;
        };
        class short: close { aiBurstTerminable = 1; };
        class medium: close { aiBurstTerminable = 1; };
        class far: close { aiBurstTerminable = 1; };
    };
    class CannonCore;
    class autocannon_Base_F: CannonCore {
        aiDispersionCoefX = 6;
        aiDispersionCoefY = 5;
    };
};
