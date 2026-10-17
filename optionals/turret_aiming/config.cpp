// Author: WaldoTheWarfighter
// Optional restart-required AI aiming policy. No projectile or player weapon properties change.
class CfgPatches {
    class CBE_policy_turret_aiming {
        name = "Combat Behaviour Enhancement (CBE) - Optional AI Turret Aiming";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Characters_F", "CBE_vehicles"};
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