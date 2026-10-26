// Author: WaldoTheWarfighter
// Restart-required native AI recovery policy. No runtime skill or weapon mutation.
class CfgPatches {
    class CBE_policy_suppression {
        name = "Combat Behaviour Enhancement (CBE) - Native Suppression Recovery";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Characters_F", "CBE_danger"};
        units[] = {};
        weapons[] = {};
    };
};
class CfgBrains {
    class DefaultSoldierBrain {
        class Components {
            class AIBrainSuppressionComponent {
                worstDecreaseTime = 25.0;
                bestDecreaseTime = 4.0;
                causeExplosionWeight = 1.5;
            };
            class AIBrainAimingErrorComponent {
                worstDecreaseTime = 3.5;
                bestDecreaseTime = 0.6;
                turningInfluence = 1.2;
            };
        };
    };
};
