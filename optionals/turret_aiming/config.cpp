// Author: WaldoTheWarfighter
// Optional restart-required AI aiming policy. No projectile or player weapon properties change.
class CfgPatches {
    class WAIT_policy_turret_aiming {
        name = "Waldos AI Tweaks - Optional AI Turret Aiming";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Characters_F", "WAIT_vehicles"};
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