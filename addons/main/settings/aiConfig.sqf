/*
 * Author: WaldoTheWarfighter
 * Defines AI rebalance selection, filters, display names and improved helicopter-landing control
 * limits, optional cruise-deceleration climb suppression and the optional Smart AI Pass. AI application and locality
 * migration remain in \z\cbe\addons\main\functions.
 * Locality / Authority: The SHARED loader reads these defaults on every machine. AI handlers
 * apply them only where they own the affected unit or aircraft.
 * Repeat/JIP: Guarded defaults leave existing values alone. A joining machine loads its local
 * defaults. AI handlers handle later locality changes and group migration.
 *
 * Schema: SHARED entries are [missionNamespace variable name, guarded default value].
 * Arguments: None.
 * Return Value: HASHMAP consumed by CBE_fnc_LoadFeatureConfigs.
 *
 * Example: change CBE_AIRebalance_Profile from LINE to MILITIA, VETERAN or ELITE.
 * Result: eligible AI receive that named CBE skill profile when the automatic handler applies it.
 * Current caller: CBE_fnc_LoadFeatureConfigs from init.sqf using the SHARED scope.
 *
 * ACTIVATION MODEL: AUTOMATIC WHEN EACH ENABLE SWITCH IS TRUE.
 * No custom call is required. AI rebalance follows AI locality on server, headless client or client;
 * improved landing watches local AI helicopter pilots with LAND/UNLOAD/TRANSPORT UNLOAD/GET OUT
 * waypoints. Setting an enable switch false prevents that handler from starting.
 *
 * EDIT FOR A NORMAL MISSION: both Enable switches, AI profile/mode/apply population and optional
 * side/faction/class filters. LEAVE ALONE UNLESS EXTENDING/TESTING: skill variance, restore policy,
 * display-name keys and every helicopter controller distance/rate/timing value.
 * CUSTOM CALLS: not required. Runtime AI profile changes should use CBE_fnc_AIRebalanceInit;
 * CBE_fnc_AIRebalanceStop restores recorded skills when RestoreOnStop is true.
 *
 * CUSTOMISATION GUIDE:
 * MISSION MAKER - enable, Profile, Mode and include/exclude filters are intended choices. Profiles
 * are MILITIA, LINE, VETERAN or ELITE; LINE is the CBE default for editor and Zeus AI. Mode is AUTO (ambient darkness), DAY
 * or NIGHT (legacy night profile). ApplyMode is BOTH, EXISTING or NEW. Side filters use WEST, EAST, GUER or CIV; faction
 * and class filters use config classnames. Empty include arrays mean unrestricted.
 * ADVANCED TUNING - SkillVariance, RestoreOnStop and every ImprovedHelicopterLanding numeric value
 * are control/safety parameters. Keep defaults unless a repeatable aircraft/terrain test requires
 * adjustment. Distances/heights are metres, rates are metres/second, intervals/times are seconds.
 *
 * HOW TO READ THE DATA BELOW:
 * `shared` rows are `[variable name, default value]`. The loader sets the default only when the
 * variable does not already exist, on every machine that may own AI. A value already supplied by
 * mission code or JIP is preserved. Mode selects lighting conditions; ApplyMode independently
 * selects which AI population receives the profile.
 *
 * SETTING-BY-SETTING GUIDE - AI REBALANCE:
 * - CBE_AIRebalance_Enable (MISSION MAKER): true applies CBE skill profiles; false leaves AI skills alone.
 * - CBE_AIRebalance_Profile (MISSION MAKER): MILITIA, LINE, VETERAN or ELITE; LINE is the normal baseline.
 * - CBE_AIRebalance_Mode (MISSION MAKER): AUTO by default follows ambient darkness; DAY disables the extra penalty; NIGHT retains legacy night tiers.
 * - CBE_AI_ApplyMode (MISSION MAKER): EXISTING, NEW or BOTH; choose which AI population receives the profile.
 * - CBE_AI_RestoreOnStop (ADVANCED): true restores the skills CBE recorded when its handler is stopped.
 * - CBE_AI_SkillVariance (ADVANCED): stable random offset chosen once per AI; 0 disables variation.
 * - CBE_AI_InfantryDispersion (ADVANCED): script-level aim coefficient for dismounted AI and vehicle cargo.
 * - CBE_AI_VehicleCrewAimMultiplier (ADVANCED): final aiming-skill multiplier for operating vehicle and aircraft crew.
 * - CBE_AI_VehicleCrewDispersion (ADVANCED): script-level aim coefficient for ground-vehicle operators when no external precision provider is active.
 * - CBE_AI_AirCrewDispersion (ADVANCED): wider script-level aim coefficient for aircraft operators when no external precision provider is active.
 * - CBE_AI_IncludedSides (MISSION MAKER): [] allows every side; example ["WEST", "GUER"] limits application.
 * - CBE_AI_IncludedFactions (MISSION MAKER): [] allows all; otherwise list CfgFactionClasses names.
 * - CBE_AI_ExcludedFactions (MISSION MAKER): listed factions are always skipped after the include checks.
 * - CBE_AI_ExcludedClasses (MISSION MAKER): exact CfgVehicles unit classes that CBE must never modify.
 *
 * SETTING-BY-SETTING GUIDE - IMPROVED HELICOPTER LANDING:
 * - CBE_ImprovedHelicopterLanding_Enable (MISSION MAKER): true watches local AI helicopter landing waypoints.
 * - CBE_ImprovedHelicopterLanding_MinimumActivationDistance (ADVANCED): waypoint must begin at least this far away.
 * - CBE_ImprovedHelicopterLanding_TriggerDistance (ADVANCED): distance at which CBE starts approach control.
 * - CBE_ImprovedHelicopterLanding_TriggerSpeedFactor (ADVANCED): scales the speed-sensitive takeover test.
 * - CBE_ImprovedHelicopterLanding_MinimumApproachSpeed (ADVANCED): minimum entry speed in km/h; prevents slow short legs.
 * - CBE_ImprovedHelicopterLanding_TransitAltitude (ADVANCED): preferred clear-ground approach height in metres AGL.
 * - CBE_ImprovedHelicopterLanding_GlideSlopeRatio (ADVANCED): horizontal travel per metre of planned descent.
 * - CBE_ImprovedHelicopterLanding_TreeScanRadius (ADVANCED): vegetation search radius around the landing point.
 * - CBE_ImprovedHelicopterLanding_TreeSafetyBuffer (ADVANCED): extra clearance above detected tree canopies.
 * - CBE_ImprovedHelicopterLanding_MaximumTreeHoverHeight (ADVANCED): ceiling on canopy-induced hover correction.
 * - CBE_ImprovedHelicopterLanding_GoAroundTriggerDistance (ADVANCED): range in which excessive height is tested.
 * - CBE_ImprovedHelicopterLanding_GoAroundHeight (ADVANCED): safe AGL climb target for a retry.
 * - CBE_ImprovedHelicopterLanding_GoAroundExitDistance (ADVANCED): distance flown clear before turning back.
 * - CBE_ImprovedHelicopterLanding_GoAroundSpeed (ADVANCED): commanded retry speed in kilometres per hour.
 * - CBE_ImprovedHelicopterLanding_MaximumGoArounds (ADVANCED): maximum automatic retries per landing order.
 * - CBE_ImprovedHelicopterLanding_MaximumClimbRate (ADVANCED): upward command clamp in metres per second.
 * - CBE_ImprovedHelicopterLanding_MaximumDescentRate (ADVANCED): downward command clamp in metres per second.
 * - CBE_ImprovedHelicopterLanding_TouchdownRadius (ADVANCED): accepted horizontal error; 5 m is the current default.
 * - CBE_ImprovedHelicopterLanding_FinalCommitDistance (ADVANCED): range at which flare/final landing begins.
 * - CBE_ImprovedHelicopterLanding_ControlInterval (ADVANCED): controller update period; lowering it costs more CPU.
 * - CBE_ImprovedHelicopterLanding_TouchdownHoldSeconds (ADVANCED): landed hold; 20 s prevents immediate takeoff.
 *
 * SETTING-BY-SETTING GUIDE - AI HELICOPTER DECELERATION:
 * - CBE_HelicopterDeceleration_Enable (MISSION MAKER): false by default until your airframes pass live testing.
 * - CBE_HelicopterDeceleration_IncludeVTOL (MISSION MAKER): false keeps VTOL flight modes out of the system.
 * - CBE_HelicopterDeceleration_MinimumSpeed (ADVANCED): minimum forward speed in km/h before detection can start.
 * - CBE_HelicopterDeceleration_MinimumAltitude (ADVANCED): minimum terrain-relative height in metres.
 * - CBE_HelicopterDeceleration_MinimumSpeedLoss (ADVANCED): required km/h lost during one sample.
 * - CBE_HelicopterDeceleration_MinimumAltitudeGain (ADVANCED): required metres climbed during one sample.
 * - CBE_HelicopterDeceleration_MinimumNoseUp (ADVANCED): minimum upward vectorDir component; 0 is level.
 * - CBE_HelicopterDeceleration_TerrainClearance (ADVANCED): required clearance above terrain ahead.
 * - CBE_HelicopterDeceleration_MaximumCorrectionAcceleration (ADVANCED): downward correction cap in m/s squared.
 * - CBE_HelicopterDeceleration_MaximumClimbRate (ADVANCED): correction ends below this upward m/s rate.
 * - CBE_HelicopterDeceleration_SampleInterval (ADVANCED): seconds between detection samples.
 * - CBE_HelicopterDeceleration_ControlInterval (ADVANCED): seconds between force corrections while active.
 * - CBE_HelicopterDeceleration_MaximumCorrectionSeconds (ADVANCED): hard duration cap for one correction.
 * - CBE_HelicopterDeceleration_Debug (TROUBLESHOOTING): logs acquire/release reasons and owner IDs.
 * Per-aircraft opt-out example: this setVariable ["CBE_HelicopterDeceleration_Exclude", true, true];
 * - CBE_AI_ProfileDisplayNames (INFRASTRUCTURE): labels for diagnostics/UI; keys must match implementation IDs.
 *
 * SETTING-BY-SETTING GUIDE - MODULAR AI BEHAVIOURS:
 * - CBE_AIPass_AmmoCapabilityOverrides (ADVANCED): magazine class to an array containing "AT" and/or "AA". Empty map uses ammunition configuration.
 * - CBE_AIPass_VehicleDismount_Enable (MISSION MAKER): Routine passenger dismounting during vehicle contact drills. Default true.
 * - CBE_AIPass_VehicleRemount_Enable (MISSION MAKER): Reboard recorded passengers on a normal return to CALM. Default true.
 * - CBE_AIPass_VehicleWithdraw_Enable (MISSION MAKER): Damaged vehicle smoke and withdrawal. Default true.
 * - CBE_AIPass_VehicleJink_Enable (MISSION MAKER): One short terrain-checked escape for an intact crewed fighting vehicle under close or severe danger. Default true.
 * - CBE_AIPass_CoverValidation_Enable (MISSION MAKER): Bounded footprint, slope and geometry validation for cover candidates. Default true.
 * - CBE_AIPass_Danger_Enable (MISSION MAKER): Enables CBE's bounded local danger reflex and tactical group handoff. Disabled means the configured FSM exits without issuing CBE commands. Default true.
 * - CBE_AIPass_DangerEvasion_Enable (MISSION MAKER): Enables finite native prone evasion; committed movement and external/native tasks yield. Default true.
 * - CBE_AIPass_DangerObservation_Enable (MISSION MAKER): Enables position-only body/scream glances for idle infantry. Requires danger response. Default true.
 * - CBE_AIPass_DangerConcealment_Enable (MISSION MAKER): Allows visual screening fallback after failed solid cover. Default true.
 * - CBE_AIPass_DangerSmoke_Enable (MISSION MAKER): Allows one carried smoke screen during severe finite danger without holding the current operation. Default true.
 * - CBE_AIPass_Illumination_Enable (MISSION MAKER): Experimental finite carried UGL illumination in darkness. Default false.
 * - CBE_AIPass_StaticSupport_Enable (MISSION MAKER): Allows one uncommitted soldier to physically occupy a nearby useful empty static weapon during confirmed contact. Default true.
 * - CBE_AIPass_StaticDeploy_Enable (MISSION MAKER): Allows a compatible two-person bag team to physically assemble and occupy its carried static weapon. Default true.
 * - CBE_AIPass_Hearing_Enable (MISSION MAKER): Coarse nearby-gunfire reports for eligible squad leaders; requires investigation. Default true.
 * - CBE_Convoy_MountedFire_Enable (MISSION MAKER): Mounted crew targeting under existing ROE. Default true.
 * - CBE_Convoy_Cover_Enable (MISSION MAKER): Short passenger movement clear of vehicles after a halt, using cover during contact. Default true.
 * - CBE_Convoy_ContactHalt_Enable (MISSION MAKER): Contact halt requests under the configured push-through rule. Default true.
 * - CBE_Convoy_Unload_Enable (MISSION MAKER): Routine cargo unloading at arrival, manual stop and ambush halt. Default true.
 * - CBE_Convoy_AvoidInfantry_Enable (MISSION MAKER): Bounded friendly-infantry corridor checks in the existing convoy speed controller. Default false.
 * - CBE_Convoy_DrivingAssist_Enable (MISSION MAKER): Low-frequency road look-ahead and speed damping for smoother curves, junctions and grades. Default true.
 * - CBE_Convoy_RouteRecovery_Enable (MISSION MAKER): Re-selects the same unchanged final MOVE waypoint when the engine completes it far from its destination. Default true.
 *
 * SETTING-BY-SETTING GUIDE - SMART AI PASS:
 * Behaviour improvements for all non-player AI groups. It runs only on the server and headless
 * clients, inside a soft per-tick time budget, with bounded reports and changed-state broadcasts. Player-led
 * groups and units owned by other CBE features (Gunship, Transport Services, Paradrop, Dynamic AA,
 * AI Convoy, dialogue speakers, drones) are always excluded. Dynamic AO groups are included.
 * Per-unit or per-group opt-out: _group setVariable ["CBE_AIPass_Exclude", true, true];
 * - CBE_AIPass_Enable (MISSION MAKER): master switch; true by default. False means no pass code runs anywhere.
 * - CBE_AIPass_IncludedSides (MISSION MAKER): sides the pass may command; CIV is left out by default.
 *   The shared CBE_AI_IncludedFactions/ExcludedFactions/ExcludedClasses filters above also apply.
 * - CBE_AIPass_TickBudgetMs (ADVANCED): milliseconds of work allowed on a frame with due jobs.
 * - CBE_AIPass_LowFpsThreshold (ADVANCED): below this machine FPS, behaviour steps run half as often.
 * - CBE_AIPass_Regroup_Enable (MISSION MAKER): survivors of a destroyed squad join a nearby friendly squad.
 * - CBE_AIPass_MedicalAssist_Enable (MISSION MAKER): a local medic physically treats a hurt squad-mate during CALM or SECURITY when no medical controller owns treatment. Default true.
 * - CBE_AIPass_MedicalAssist_Range (ADVANCED): maximum medic-to-casualty selection distance in metres.
 * - CBE_AIPass_MedicalAssist_DamageThreshold (ADVANCED): minimum engine damage before CBE considers vanilla assistance.
 * - CBE_AIPass_MedicalAssist_Timeout (ADVANCED): finite treatment attempt limit; failure releases without health changes.
 * - CBE_AIPass_Regroup_MaxRemnantSize (ADVANCED): a group this small or smaller counts as a remnant.
 * - CBE_AIPass_Regroup_MinimumPeakSize (ADVANCED): groups that never reached this size (snipers,
 *   sentries) are never merged.
 * - CBE_AIPass_Regroup_SearchRadius (ADVANCED): metres searched for a host squad.
 * - CBE_AIPass_Regroup_MaxGroupSize (ADVANCED): a host may not exceed this size after the merge.
 * - CBE_AIPass_Regroup_JoinDistance (ADVANCED): survivors join once this close to the host leader.
 * - CBE_AIPass_Regroup_StuckSeconds (ADVANCED): no progress for this long retries once, then aborts without merging at a distance.
 * - CBE_AIPass_Regroup_TimeoutSeconds (ADVANCED): limit for finding a host and for walking to it.
 * - CBE_AIPass_Regroup_SettleSeconds (ADVANCED): wait after a kill so simultaneous deaths settle.
 * - CBE_AIPass_CivilianReaction_Enable (MISSION MAKER): event-driven unarmed civilian flight from nearby danger. Player, Zeus and neutral external-control ownership take priority.
 * - CBE_AIPass_CivilianReaction_Radius (ADVANCED): FiredNear distance which may trigger flight.
 * - CBE_AIPass_CivilianReaction_Distance (ADVANCED): approximate one-shot escape distance.
 * - CBE_AIPass_CivilianReaction_Cooldown (ADVANCED): minimum seconds before another response.
 * - CBE_AIPass_Debug (TROUBLESHOOTING): logs contact, flank, morale and retreat events to RPT.
 * - CBE_AIPass_EngageRange (ADVANCED): range in metres within which known enemies are considered.
 * - CBE_AIPass_NearRange (ADVANCED): squads this close to a player are stepped every TickNear seconds.
 * - CBE_AIPass_FarRange (ADVANCED): beyond this distance from every player only the state ladder and morale run.
 * - CBE_AIPass_TickContact (ADVANCED): seconds between steps for a squad in contact near players.
 * - CBE_AIPass_TickNear (ADVANCED): seconds between steps within NearRange.
 * - CBE_AIPass_TickMid (ADVANCED): seconds between steps within FarRange.
 * - CBE_AIPass_TickFar (ADVANCED): seconds between steps beyond FarRange.
 * - CBE_AIPass_DiscoveryInterval (ADVANCED): seconds between discovery sweeps for newly local AI groups.
 * - CBE_AIPass_Contact_Enable (MISSION MAKER): contact handling and the state ladder; every combat behaviour below needs it.
 * - CBE_AIPass_PostContact_Enable (MISSION MAKER): after contact is lost: hold, search the last known enemy position, regroup.
 * - CBE_AIPass_PostContact_LostSeconds (ADVANCED): seconds without a sighting before contact counts as lost.
 * - CBE_AIPass_PostContact_SecuritySeconds (ADVANCED): seconds of security hold before the search.
 * - CBE_AIPass_PostContact_SearchSeconds (ADVANCED): time limit for the two-man search.
 * - CBE_AIPass_PostContact_RegroupSeconds (ADVANCED): time limit for the squad to close up before returning to CALM.
 * - CBE_AIPass_Flank_Enable (MISSION MAKER): half the squad flanks in covered bounds while the rest suppresses.
 * - CBE_AIPass_Flank_MinGroupSize (ADVANCED): soldiers on foot needed before a squad may flank.
 * - CBE_AIPass_Flank_MinRange (ADVANCED): enemies nearer than this are fought, not flanked.
 * - CBE_AIPass_Flank_MaxRange (ADVANCED): enemies farther than this are not flanked.
 * - CBE_AIPass_Flank_BoundDistance (ADVANCED): length of one bound in metres.
 * - CBE_AIPass_Flank_BoundPause (ADVANCED): optional deliberate overwatch seconds after physical arrival; zero keeps movement continuous.
 * - CBE_AIPass_Flank_BoundTimeout (ADVANCED): seconds without two metres of progress before a bound aborts; absolute bound limit is four times this value. Never counts as arrival.
 * - CBE_AIPass_Flank_Cooldown (ADVANCED): seconds before the same squad may flank again.
 * - CBE_AIPass_StreetCrossing_Enable (MISSION MAKER): flanking elements stop at roads, throw smoke and cross in one bound.
 * - CBE_AIPass_FireControl_Enable (MISSION MAKER): close threats first, fire spread across visible enemies, and staggered alternating suppression between squads.
 * - CBE_AIPass_FireControl_MaxSuppressors (ADVANCED): soldiers allowed to suppress at the same time.
 * - CBE_AIPass_FireControl_MaxShootersPerTarget (ADVANCED): shooters on one visible enemy before extra shooters switch targets.
 * - CBE_AIPass_Morale_Enable (MISSION MAKER): squads under losses and fire break and fall back under smoke.
 * - CBE_AIPass_Morale_RetreatDistance (ADVANCED): how far a broken squad falls back.
 * - CBE_AIPass_Surrender_Enable (MISSION MAKER): the last one or two survivors of a broken, isolated squad surrender (ACE Captives when loaded).
 * - CBE_AIPass_GrenadeEvasion_Enable (MISSION MAKER): AI move away from a live grenade they can see; enabled by default, with live compatibility testing required.
 * - CBE_AIPass_AntiArmour_Enable (MISSION MAKER): the best anti-tank gunner engages known armour, clear of backblast.
 * - CBE_AIPass_Vehicles_Enable (MISSION MAKER): infantry dismount under fire and remount afterwards; damaged vehicles smoke and withdraw.
 * - CBE_AIPass_NavalAssault_Enable (MISSION MAKER): AI boat crews make one finite shallow-water approach and deliver their embarked infantry onto dry ground. Default true; player, Zeus and neutral external-control ownership take priority.
 * - CBE_AIPass_ContactReports_Enable (MISSION MAKER): squads share sighted enemies by radio (blocked by jamming) or by voice.
 * - CBE_AIPass_ContactReports_Radius (ADVANCED): radio report range in metres.
 * - CBE_AIPass_ContactReports_VoiceRange (ADVANCED): report range in metres when AI transmission is blocked.
 * - CBE_Cortex_CombinedArms_AirRange (ADVANCED): operational radius for radio-linked aircraft support opportunities.
 * - CBE_AIPass_ContactReports_RequireRadio (ADVANCED): legacy compatibility setting; inventory radios are no longer checked. Jamming still applies.
 * - CBE_AIPass_Reinforce_Enable (MISSION MAKER): idle nearby squads move up behind a squad in contact.
 * - CBE_AIPass_Reinforce_Radius (ADVANCED): how far away responding squads may be.
 * - CBE_AIPass_Reinforce_MaxResponders (ADVANCED): responding squads per squad in contact.
 * - Difficulty (MISSION MAKER; all of these, and the support, artillery, counter-battery and airborne
 *   numbers below, can be changed during the mission with the AI Tuning Zeus module or
 *   CBE_fnc_CortexTuning):
 *   - CBE_AIPass_BehaviourProfile: "" follows the AI Rebalance profile; MILITIA, LINE, VETERAN or ELITE sets squad tactics mission-wide (group and faction profiles still win).
 *   - CBE_AIPass_Aggression: scales local-manoeuvre preferences, optional assault preparation,
 *     post-contact investigation and coordinated-assault participation (1 = the profile's own).
 *   - CBE_AIPass_Cohesion: how much punishment squads take before morale breaks (1 = normal).
 *   - CBE_AIPass_ReactionSpeed: how often squads re-assess (1 = normal; higher costs more server time).
 * - CBE_AIPass_Artillery_Enable (MISSION MAKER): squads call fire from friendly AI artillery on well-located enemies only.
 * - CBE_AIPass_Artillery_Bursts (ADVANCED): Maximum HE bursts per mission; smoke uses one burst.
 * - CBE_AIPass_Artillery_RoundInterval (ADVANCED): Minimum seconds between confirmed rounds inside one burst.
 * - CBE_AIPass_Artillery_LocationResetDistance (ADVANCED): Reported movement in metres that resets opening offset and safety checks.
 * - CBE_AIPass_CounterBattery_RadarDelay (ADVANCED): Counter-battery acquisition seconds with radar coverage; capped by the normal delay.
 * - CBE_AIPass_Artillery_Rounds (ADVANCED): rounds per support burst.
 * - CBE_AIPass_Artillery_OpeningSafeDistance (ADVANCED): opening HE aim exclusion around living players; default 200 m.
 * - CBE_AIPass_Artillery_OpeningBuffer (ADVANCED): extra opening aim margin; default 100 m, not an impact guarantee.
 * - CBE_AIPass_Artillery_WarningInterval (ADVANCED): pause after the last estimated burst impact before the next burst; default 20 s.
 * - CBE_AIPass_Artillery_MinFriendlyDistance (ADVANCED): no mission lands within this distance of friendlies or civilians.
 * - CBE_AIPass_Artillery_MaxError (ADVANCED): largest target position error accepted for a mission.
 * - CBE_AIPass_Artillery_Cooldown (ADVANCED): seconds between missions called by one squad.
 * - CBE_AIPass_Artillery_ShootAndScoot (ADVANCED): mobile batteries move 200-350 m after a support mission.
 * - CBE_AIPass_Artillery_DefaultRole (MISSION MAKER): missions a battery takes unless you set its own role: SUPPORT (squads' calls only), COUNTER (counter-battery only) or BOTH. Per gun: [this, "COUNTER"] call CBE_fnc_CortexSetArtilleryRole; or the AI Orders Zeus module.
 * - CBE_AIPass_CounterBattery_Enable (MISSION MAKER): AI artillery answers enemy artillery whose position is known.
 * - CBE_AIPass_CounterBattery_Mode (MISSION MAKER): legacy compatibility setting; firing events wake fresh observers or registered radar acquisition.
 * - CBE_AIPass_CounterBattery_RadarRange (ADVANCED): detection range of a registered counter-battery radar.
 * - CBE_AIPass_CounterBattery_Delay (ADVANCED): acquisition seconds without radar (default 60).
 * - CBE_AIPass_CounterBattery_Rounds (ADVANCED): rounds per counter-battery burst.
 * - CBE_AIPass_CounterBattery_MaxError (ADVANCED): largest position error on the enemy gun accepted in KNOWN mode.
 * - CBE_AIPass_CounterBattery_MinFriendlyDistance (ADVANCED): no counter-battery fire when friendlies or civilians are this close to the enemy gun.
 * - CBE_AIPass_CounterBattery_Interval (ADVANCED): seconds before the same enemy gun is answered again.
 * - CBE_AIPass_CounterBattery_ShootAndScoot (ADVANCED): mobile batteries move 200-350 m after a counter-battery mission.
 * - CBE_AIPass_Airborne_Enable (MISSION MAKER): AI squads riding in AI-flown helicopters or planes parachute out when their aircraft nears a known enemy. Helicopters on an unload or get-out waypoint still land. [group this] call CBE_fnc_CortexAirborneDrop orders a drop at any time.
 * - CBE_AIPass_Airborne_ApproachDistance (ADVANCED): within this distance of a known enemy the aircraft climbs to jump altitude.
 * - CBE_AIPass_Airborne_DeployDistance (MISSION MAKER): the squad jumps once its aircraft is this close to a known enemy.
 * - CBE_AIPass_Airborne_Altitude (ADVANCED): height above ground the aircraft climbs to for the drop.
 * - CBE_AIPass_Airborne_MinAltitude (ADVANCED): never jump below this height above ground (or over water).
 * - CBE_AIPass_Airborne_JumpInterval (ADVANCED): seconds between jumpers.
 * - CBE_AIPass_Garrison_BreakFraction (ADVANCED): a garrison or defence line breaks when down to this share of its strength at the time of the order.
 * - CBE_Cortex_AttackRunFlares_Enable (MISSION MAKER): AI planes and helicopters with an assigned hostile target make finite countermeasure requests while closing on the attack run and again after passing their closest approach. This does not create ammunition or alter the flight path.
 * - CBE_Cortex_AirAttack_Enable (MISSION MAKER): eligible airborne AI choose finite strafe, offset, helicopter-hook or standoff attack geometry from observed AA and live weapon capability, then cleanly return to an unchanged authored order.
 * - CBE_AIPass_AircraftFlares_Enable (MISSION MAKER): eligible AI aircraft fire flares at incoming missiles; test addon aircraft first.
 * - CBE_AIPass_ProfileBehaviour (ADVANCED): behaviour per profile name, alongside AI Rebalance's skill
 *   values (which the pass never changes): flank, assault, advance, investigate and coordinated-assault
 *   chances (0-1), morale thresholds, retreat distance scale and the largest squad that may surrender.
 *   A group uses CBE_AIPass_Profile set on the group, then CBE_AIPass_FactionProfiles, then the
 *   active CBE_AIRebalance_Profile, then LINE.
 * - CBE_AIPass_FactionProfiles (MISSION MAKER): optional map of faction classname to behaviour profile name, overriding the AI Rebalance profile for that faction's squads.
 * - CBE_AIPass_ZeusHoldSeconds (MISSION MAKER): seconds the pass leaves a group alone after a direct Zeus edit; Zeus waypoints hold movement until they finish and then release immediately.
 * - CBE_AIPass_Investigate_Enable (MISSION MAKER): squads send two riflemen (the whole squad beyond 150 m) to check enemies they know about but have not seen (reported, or heard firing).
 * - CBE_AIPass_Investigate_Range (ADVANCED): how far away a known but unseen enemy may be to be investigated.
 * - CBE_AIPass_Investigate_Seconds (ADVANCED): time limit for an investigation.
 * - CBE_AIPass_Assault_Enable (MISSION MAKER): an eligible manoeuvre finishes with a paired-element clear-through; a fresh known threat already inside ordinary manoeuvre range can start it directly.
 * - CBE_AIPass_Assault_Range (ADVANCED): maximum transition range for a final assault; direct close assault remains capped at 60 metres.
 * - CBE_AIPass_BuildingCombat_Enable (MISSION MAKER): a capable squad may enter a usable building containing a recent, engine-confirmed hostile.
 * - CBE_AIPass_BuildingCombat_Range (ADVANCED): maximum range for natural hostile-building entry; explicit clearance orders are unaffected.
 * - CBE_AIPass_Advance_Enable (MISSION MAKER): squads in a long firefight that still have a waypoint to reach push a fire team forward in covered bounds.
 * - CBE_AIPass_Advance_MinContactSeconds (ADVANCED): seconds in contact before a bounding advance is considered.
 * - CBE_AIPass_Advance_Cooldown (ADVANCED): seconds before a squad may begin another bounding advance.
 * - CBE_AIPass_CoordinatedAssault_Enable (MISSION MAKER): squads that came to reinforce assault the enemy from both sides while the squad in contact fires.
 * - CBE_AIPass_Stance_Enable (MISSION MAKER): soldiers stand, kneel or go prone to match the cover in front of them.
 * - CBE_AIPass_AmmoShare_Enable (MISSION MAKER): soldiers down to their last magazine get one from a nearby squad-mate with plenty.
 * - CBE_AIPass_AmmoShare_Distance (ADVANCED): how close a squad-mate must be to hand over a magazine.
 * - CBE_AIPass_VehicleGunnery_Enable (MISSION MAKER): AI gunners engage anti-tank soldiers first, then armour; armour backs away from known AT teams.
 * - CBE_AIPass_Vehicles_StandoffDistance (ADVANCED): distance armour tries to keep from known anti-tank soldiers.
 * - CBE_AIPass_ArtillerySmoke_Enable (MISSION MAKER): an unjammed retreating squad gets an artillery smoke screen; needs artillery support on and a battery with smoke.
 * - CBE_AIPass_AircraftBreak_Enable (MISSION MAKER): eligible AI aircraft jink sideways away from a missile launch; test addon aircraft first.
 */
createHashMapFromArray [
    ["featureFamilies", ["AI Rebalance", "Improved AI Helicopter Landings", "AI Helicopter Deceleration", "Smart AI Pass"]],
    ["shared", [
        ["CBE_AIPass_AmmoCapabilityOverrides", createHashMap], // MAP: magazine class to ["AT"] / ["AA"] / ["AT","AA"] role overrides.
        // MISSION MAKER: AI population, profile and filtering policy.
        ["CBE_AIRebalance_Enable", false],         // BOOL: opt in to CBE skill profiles; mission skills are preserved by default.
        ["CBE_AIRebalance_Profile", "LINE"],      // STRING: MILITIA, LINE, VETERAN or ELITE.
        ["CBE_AIRebalance_Mode", "AUTO"],          // STRING: AUTO ambient-darkness/NVG aware; DAY override; NIGHT legacy variant.
        ["CBE_AI_ApplyMode", "BOTH"],             // STRING: EXISTING, NEW or BOTH AI populations.
        ["CBE_AI_RestoreOnStop", true],            // ADVANCED: restore captured vanilla/mission skills on stop.
        ["CBE_AI_SkillVariance", 0],               // ADVANCED: one stable per-AI offset; 0 disables variation.
        ["CBE_AI_InfantryDispersion", 1.35],       // ADVANCED: modest owner-local dispersion for dismounted AI and cargo.
        ["CBE_AI_VehicleCrewAimMultiplier", 0.6],  // ADVANCED: vehicle/aircraft operating crew retain the selected profile at reduced precision.
        ["CBE_AI_VehicleCrewDispersion", 3.5],     // ADVANCED: ground-vehicle aim coefficient; skipped when an external precision provider supplies configuration dispersion.
        ["CBE_AI_AirCrewDispersion", 4.25],        // ADVANCED: aircraft aim coefficient; Dynamic AA remains exempt.
        ["CBE_AI_IncludedSides", []],             // ARRAY of WEST/EAST/GUER/CIV strings; [] permits every side.
        ["CBE_AI_IncludedFactions", []],          // ARRAY of CfgFactionClasses names; [] permits every faction.
        ["CBE_AI_ExcludedFactions", []],          // ARRAY of faction names removed after the include filter.
        ["CBE_AI_ExcludedClasses", []],           // ARRAY of exact CfgVehicles unit classnames never changed.
        // MISSION MAKER master switch followed by ADVANCED landing-controller tuning.
        ["CBE_ImprovedHelicopterLanding_Enable", true], // BOOL: watches eligible landing waypoints for local AI pilots.
        ["CBE_ImprovedHelicopterLanding_MinimumActivationDistance", 50], // METRES: waypoint must start at least this far away.
        ["CBE_ImprovedHelicopterLanding_TriggerDistance", 500], // METRES: controller takes over inside this distance.
        ["CBE_ImprovedHelicopterLanding_TriggerSpeedFactor", 4.2], // MULTIPLIER: approach-speed trigger scaling.
        ["CBE_ImprovedHelicopterLanding_MinimumApproachSpeed", 55], // KM/H: minimum speed when scripted approach control begins.
        ["CBE_ImprovedHelicopterLanding_TransitAltitude", 30], // METRES AGL: clear-terrain approach height.
        ["CBE_ImprovedHelicopterLanding_GlideSlopeRatio", 4], // RATIO: horizontal distance per metre of descent.
        ["CBE_ImprovedHelicopterLanding_TreeScanRadius", 25], // METRES: vegetation search around touchdown.
        ["CBE_ImprovedHelicopterLanding_TreeSafetyBuffer", 5], // METRES: clearance added above detected canopy.
        ["CBE_ImprovedHelicopterLanding_MaximumTreeHoverHeight", 40], // METRES: canopy correction ceiling.
        ["CBE_ImprovedHelicopterLanding_GoAroundTriggerDistance", 200], // METRES: assess excessive height inside this range.
        ["CBE_ImprovedHelicopterLanding_GoAroundHeight", 150], // METRES AGL: climb target during a go-around.
        ["CBE_ImprovedHelicopterLanding_GoAroundExitDistance", 250], // METRES: distance flown clear before re-approach.
        ["CBE_ImprovedHelicopterLanding_GoAroundSpeed", 70], // KM/H: commanded go-around speed.
        ["CBE_ImprovedHelicopterLanding_MaximumGoArounds", 1], // COUNT: maximum automatic retries for one landing order.
        ["CBE_ImprovedHelicopterLanding_MaximumClimbRate", 8], // METRES/SECOND: vertical command clamp.
        ["CBE_ImprovedHelicopterLanding_MaximumDescentRate", 10], // METRES/SECOND: descent command clamp.
        ["CBE_ImprovedHelicopterLanding_TouchdownRadius", 5], // METRES: accepted horizontal error. Larger is easier but less exact.
        ["CBE_ImprovedHelicopterLanding_FinalCommitDistance", 75], // METRES: begin the final flare/landing phase.
        ["CBE_ImprovedHelicopterLanding_ControlInterval", 0.05], // SECONDS: local control-loop interval; performance-sensitive.
        ["CBE_ImprovedHelicopterLanding_TouchdownHoldSeconds", 20], // SECONDS: keep the AI landed before releasing controls; prevents immediate takeoff.
        // MISSION MAKER switches followed by ADVANCED cruise-deceleration safety limits.
        ["CBE_HelicopterDeceleration_Enable", false], // BOOL: suppress AI zoom-climb while braking; test airframes before enabling.
        ["CBE_HelicopterDeceleration_IncludeVTOL", false], // BOOL: include VTOL_Base_F aircraft; false is the conservative default.
        ["CBE_HelicopterDeceleration_MinimumSpeed", 80], // KM/H: detection is ignored below this airspeed.
        ["CBE_HelicopterDeceleration_MinimumAltitude", 25], // METRES AGL: never correct close to terrain.
        ["CBE_HelicopterDeceleration_MinimumSpeedLoss", 4], // KM/H PER SAMPLE: braking threshold.
        ["CBE_HelicopterDeceleration_MinimumAltitudeGain", 0.5], // METRES PER SAMPLE: unwanted climb threshold.
        ["CBE_HelicopterDeceleration_MinimumNoseUp", 0.02], // VECTOR DIR Z: positive nose-up threshold.
        ["CBE_HelicopterDeceleration_TerrainClearance", 25], // METRES: required clearance over terrain 100/300/500 m ahead.
        ["CBE_HelicopterDeceleration_MaximumCorrectionAcceleration", 2.5], // M/S^2: downward world-force cap.
        ["CBE_HelicopterDeceleration_MaximumClimbRate", 0.5], // M/S: release once vertical climb falls to this value.
        ["CBE_HelicopterDeceleration_SampleInterval", 0.5], // SECONDS: local detection cadence.
        ["CBE_HelicopterDeceleration_ControlInterval", 0.02], // SECONDS: active correction cadence.
        ["CBE_HelicopterDeceleration_MaximumCorrectionSeconds", 4], // SECONDS: hard cap per correction event.
        ["CBE_HelicopterDeceleration_Debug", false], // BOOL: detailed RPT acquire/release logging.
        // MISSION MAKER switches followed by ADVANCED Smart AI Pass scheduling and behaviour tuning.
        ["CBE_AIPass_Enable", true], // BOOL: master switch for Cortex (server and headless clients only).
        ["CBE_AIPass_IncludedSides", ["WEST", "EAST", "GUER"]], // ARRAY of WEST/EAST/GUER/CIV strings the pass may command.
        ["CBE_AIPass_TickBudgetMs", 1], // MILLISECONDS: work allowed on a frame with due jobs; at least one due job always runs.
        ["CBE_AIPass_LowFpsThreshold", 25], // FPS: below this, behaviour steps are rescheduled half as often.
        ["CBE_AIPass_Regroup_Enable", true], // BOOL: survivors of a destroyed squad regroup with a nearby friendly squad.
        ["CBE_AIPass_MedicalAssist_Enable", true], // BOOL: local vanilla medic assistance during CALM/SECURITY; yields to medical controllers.
        ["CBE_AIPass_MedicalAssist_Range", 80], // METRES: maximum eligible medic-to-casualty selection distance.
        ["CBE_AIPass_MedicalAssist_DamageThreshold", 0.35], // DAMAGE: minimum engine damage considered for treatment.
        ["CBE_AIPass_MedicalAssist_Timeout", 45], // SECONDS: bounded native treatment attempt before release.
        ["CBE_AIPass_Regroup_MaxRemnantSize", 2], // COUNT: living members at or below this make a remnant.
        ["CBE_AIPass_Regroup_MinimumPeakSize", 3], // COUNT: smaller deliberate teams are never merged.
        ["CBE_AIPass_Regroup_SearchRadius", 400], // METRES: host squad search radius.
        ["CBE_AIPass_Regroup_MaxGroupSize", 12], // COUNT: host size limit after the merge.
        ["CBE_AIPass_Regroup_JoinDistance", 30], // METRES: survivors join the host inside this distance.
        ["CBE_AIPass_Regroup_StuckSeconds", 20], // SECONDS: without progress, retry once then abort without a remote merge.
        ["CBE_AIPass_Regroup_TimeoutSeconds", 120], // SECONDS: limit for finding a host and for walking to it.
        ["CBE_AIPass_Regroup_SettleSeconds", 5], // SECONDS: delay after a kill before the remnant is assessed.
        ["CBE_AIPass_BehaviourProfile", ""], // STRING: "" follows the AI Rebalance profile; MILITIA, LINE, VETERAN or ELITE sets squad tactics for every squad without its own.
        ["CBE_AIPass_Aggression", 1.2], // 0-2: scales manoeuvre preference/participation and optional tactical actions; zero excludes them.
        ["CBE_AIPass_Cohesion", 1], // 0.5-2: above 1 squads take more before morale breaks, below 1 they break sooner.
        ["CBE_AIPass_ReactionSpeed", 1], // 0.5-2: above 1 squads re-assess more often (more server time), below 1 less often.
        ["CBE_AIPass_CivilianReaction_Enable", true], // BOOL: event-driven unarmed civilian flight; yields to player, Zeus and neutral external-control ownership.
        ["CBE_AIPass_CivilianReaction_Radius", 45], // METRES: nearby gunfire trigger range.
        ["CBE_AIPass_CivilianReaction_Distance", 180], // METRES: approximate finite escape leg.
        ["CBE_AIPass_CivilianReaction_Cooldown", 20], // SECONDS: minimum time between new flee orders.
        ["CBE_AIPass_Debug", false], // BOOL: extra [CBE] RPT lines for contact, flanks, morale and retreats.
        ["CBE_AIPass_EngageRange", 800], // METRES: enemies the leader knows about within this range are considered.
        ["CBE_AIPass_NearRange", 1000], // METRES: squads this close to a player run at the near cadence.
        ["CBE_AIPass_FarRange", 2500], // METRES: beyond this only the state ladder and morale run.
        ["CBE_AIPass_TickContact", 2], // SECONDS: step interval for a squad in contact near players.
        ["CBE_AIPass_TickNear", 4], // SECONDS: step interval within NearRange.
        ["CBE_AIPass_TickMid", 8], // SECONDS: step interval within FarRange.
        ["CBE_AIPass_TickFar", 20], // SECONDS: step interval beyond FarRange.
        ["CBE_AIPass_DiscoveryInterval", 10], // SECONDS: how often each machine looks for newly local AI groups.
        ["CBE_AIPass_Contact_Enable", true], // BOOL: contact state ladder; needed by every combat behaviour.
        ["CBE_AIPass_PostContact_Enable", true], // BOOL: hold, search the last known position, regroup after contact.
        ["CBE_AIPass_PostContact_LostSeconds", 30], // SECONDS: without a sighting before contact counts as lost.
        ["CBE_AIPass_PostContact_SecuritySeconds", 10], // SECONDS: security hold before searching.
        ["CBE_AIPass_PostContact_SearchSeconds", 45], // SECONDS: search time limit.
        ["CBE_AIPass_PostContact_RegroupSeconds", 30], // SECONDS: regroup time limit.
        ["CBE_AIPass_Flank_Enable", true], // BOOL: base of fire plus a flanking element in covered bounds.
        ["CBE_AIPass_Flank_MinGroupSize", 6], // COUNT: soldiers on foot needed to flank.
        ["CBE_AIPass_Flank_MinRange", 60], // METRES: nearer enemies are fought, not flanked.
        ["CBE_AIPass_Flank_MaxRange", 400], // METRES: farther enemies are not flanked.
        ["CBE_AIPass_Flank_BoundDistance", 55], // METRES: length of one bound (minimum 15).
        ["CBE_AIPass_Flank_BoundPause", 0], // SECONDS: optional deliberate overwatch after physical arrival; zero keeps movement continuous.
        ["CBE_AIPass_Flank_BoundTimeout", 25], // SECONDS without progress before abort; absolute bound limit is 4x. Never counts as arrival.
        ["CBE_AIPass_Flank_Cooldown", 90], // SECONDS: before the same squad flanks again.
        ["CBE_AIPass_StreetCrossing_Enable", true], // BOOL: flanks stop at roads, smoke, and cross in one bound.
        ["CBE_AIPass_FireControl_Enable", true], // BOOL: close threats, fire distribution, staggered alternating suppression.
        ["CBE_AIPass_FireControl_MaxSuppressors", 2], // COUNT: soldiers suppressing at once.
        ["CBE_AIPass_FireControl_MaxShootersPerTarget", 2], // COUNT: shooters per visible enemy before others switch.
        ["CBE_AIPass_Morale_Enable", true], // BOOL: weighted morale; broken squads retreat under smoke.
        ["CBE_AIPass_Morale_RetreatDistance", 200], // METRES: how far a broken squad falls back.
        ["CBE_AIPass_Surrender_Enable", true], // BOOL: last survivors of a broken, isolated squad surrender.
        ["CBE_AIPass_GrenadeEvasion_Enable", true], // BOOL: move away from seen grenades.
        ["CBE_AIPass_AntiArmour_Enable", true], // BOOL: best AT gunner engages known armour, clear of backblast.
        ["CBE_AIPass_VehicleDismount_Enable", true], // Unloads capable passengers only when safely stopped on dry ground.
        ["CBE_AIPass_VehicleRemount_Enable", true], // Allows safe conscious passengers to reboard after Smart AI contact. Convoy resume stays explicit.
        ["CBE_AIPass_VehicleReverse_Enable", true], // Tracked armour attempts one bounded threat-facing reverse leg.
        ["CBE_AIPass_VehicleReverse_Distance", 30],
        ["CBE_AIPass_VehicleReverse_Timeout", 20],
        ["CBE_AIPass_VehicleReverse_FacingTolerance", 35],
        ["CBE_AIPass_VehicleWithdraw_Enable", true], // Allows damaged vehicles to withdraw and use existing smoke.
        ["CBE_AIPass_VehicleJink_Enable", true], // One bounded escape by an eligible intact fighting vehicle.
        ["CBE_AIPass_CoverValidation_Enable", true], // Adds bounded slope and body clearance checks to shared cover selection.
        ["CBE_Convoy_DefaultSpeed", 30], // New convoy order speed; existing registrations retain selected values.
        ["CBE_Convoy_DefaultSeparation", 30], // New convoy order centre spacing.
        ["CBE_Convoy_DefaultPushThrough", true], // New convoy order contact policy.
        ["CBE_Convoy_MountedFire_Enable", true], // CBE assigns targets to weapon crew under existing ROE. Disable to leave targeting to another AI mod.
        ["CBE_Convoy_Cover_Enable", true], // Moves dismounted passengers clear of vehicles; seeks cover during contact.
        ["CBE_Convoy_AvoidInfantry_Enable", false], // Optional short-range friendly infantry corridor checks before driving.
        ["CBE_Convoy_DrivingAssist_Enable", true], // Low-frequency road look-ahead and speed damping; no obstacle bypass or alternate route ownership.
        ["CBE_Convoy_RouteRecovery_Enable", true], // Re-selects only the same unchanged final MOVE waypoint after premature engine completion; never creates, teleports or repairs.
        ["CBE_Convoy_ContactHalt_Enable", true], // Automatic ambush halt using push-through and pinned rules. Route arrival and explicit stop remain available.
        ["CBE_Convoy_Unload_Enable", true], // Allows CBE passenger unloading on halt. Operating crews remain aboard.
        ["CBE_AIPass_Danger_Enable", true], // Bounded danger events; one shared decision owner.
        ["CBE_AIPass_DangerEvasion_Enable", true], // Finite native idle prone evasion.
        ["CBE_AIPass_DangerObservation_Enable", true], // Position-only idle alert observation.
        ["CBE_AIPass_DangerConcealment_Enable", true], // Separately budgeted visual screening fallback.
        ["CBE_AIPass_DangerSmoke_Enable", true], // One generation-scoped carried smoke response; movement does not wait.
        ["CBE_AIPass_Illumination_Enable", false], // Opt-in until physical illumination/handback validation.
        ["CBE_AIPass_StaticSupport_Enable", true], // One actor may occupy a nearby empty friendly static without holding squad movement.
        ["CBE_AIPass_StaticDeploy_Enable", true], // A compatible pair may physically assemble a carried static without holding squad movement.
        ["CBE_AIPass_Hearing_Enable", true], // Nearby gunfire area reports, never target reveals.
        ["CBE_AIPass_Vehicles_Enable", true], // BOOL: dismount under fire; damaged vehicles smoke and withdraw.
        ["CBE_AIPass_DrivingAssist_Enable", true], // Sparse terrain-grade speed cap for ordinary AI ground vehicles; preserves native routes.
        ["CBE_AIPass_DrivingAssist_Passing_Enable", false], // Experimental finite automatic admission; physical/performance acceptance pending.
        ["CBE_AIPass_DrivingAssist_Queue_Enable", false], // Opt-in cooperative head-on jam initiation; physical/performance acceptance pending.
        ["CBE_AIPass_DrivingAssist_MaxSpeed", 70], // General driving cap in km/h; terrain and lower authored caps still apply.
        ["CBE_AIPass_DrivingAssist_Recovery_Enable", true], // Allows new finite recovery attempts; does not cancel a native leg already issued.
        ["CBE_AIPass_NavalAssault_Enable", true], // BOOL: finite coastal approach and passenger landing; yields to player, Zeus and neutral external-control ownership.
        ["CBE_AIPass_ContactReports_Enable", true], // BOOL: share sightings by radio (jammable) or voice.
        ["CBE_AIPass_ContactReports_Radius", 500], // METRES: radio report range.
        ["CBE_AIPass_ContactReports_VoiceRange", 35], // METRES: report range when AI transmission is blocked.
        ["CBE_Cortex_CombinedArms_AirRange", 4000], // METRES: radio-linked aircraft support opportunity radius.
        ["CBE_AIPass_ContactReports_RequireRadio", false], // Legacy compatibility only: AI inventory radios are no longer checked.
        ["CBE_AIPass_Reinforce_Enable", true], // BOOL: idle nearby squads move up behind a squad in contact.
        ["CBE_AIPass_Reinforce_Radius", 600], // METRES: how far away responders may be.
        ["CBE_AIPass_Reinforce_MaxResponders", 2], // COUNT: responding squads per squad in contact.
        ["CBE_AIPass_Artillery_Enable", false], // BOOL: squads call fire from friendly AI artillery on well-located enemies.
        ["CBE_AIPass_Artillery_OpeningSafeDistance", 200], // Advanced artillery ranging control.
        ["CBE_AIPass_Artillery_OpeningBuffer", 100], // Advanced artillery ranging control.
        ["CBE_AIPass_Artillery_WarningInterval", 20], // Advanced artillery ranging control.
        ["CBE_AIPass_Artillery_Bursts", 3], // Maximum HE bursts per mission; smoke uses one burst.
        ["CBE_AIPass_Artillery_RoundInterval", 2], // Minimum seconds between confirmed rounds inside one burst.
        ["CBE_AIPass_Artillery_LocationResetDistance", 150], // Reported movement in metres that resets opening offset and safety checks.
        ["CBE_AIPass_CounterBattery_RadarDelay", 20], // Counter-battery acquisition seconds with radar coverage; capped by the normal delay.
        ["CBE_AIPass_Artillery_Rounds", 3], // COUNT: rounds per support burst.
        ["CBE_AIPass_Artillery_MinFriendlyDistance", 200], // METRES: no mission near friendlies or civilians.
        ["CBE_AIPass_Artillery_MaxError", 50], // METRES: largest target position error accepted.
        ["CBE_AIPass_Artillery_Cooldown", 120], // SECONDS: between missions called by one squad.
        ["CBE_AIPass_Artillery_ShootAndScoot", true], // BOOL: mobile batteries relocate after a support mission.
        ["CBE_AIPass_Artillery_DefaultRole", "BOTH"], // STRING: SUPPORT, COUNTER or BOTH for guns with no role of their own.
        ["CBE_AIPass_CounterBattery_Enable", false], // BOOL: AI artillery answers enemy artillery whose position is known.
        ["CBE_AIPass_CounterBattery_Mode", "AUTO"], // Legacy compatibility: automatic wakeup still requires radar or fresh observer detection.
        ["CBE_AIPass_CounterBattery_RadarRange", 8000], // METRES: radar detection range.
        ["CBE_AIPass_CounterBattery_Delay", 60], // SECONDS: before counter-battery fire.
        ["CBE_AIPass_CounterBattery_Rounds", 4], // COUNT: rounds per counter-battery burst.
        ["CBE_AIPass_CounterBattery_MaxError", 100], // METRES: largest enemy-gun position error accepted (KNOWN).
        ["CBE_AIPass_CounterBattery_MinFriendlyDistance", 200], // METRES: no fire near friendlies or civilians.
        ["CBE_AIPass_CounterBattery_Interval", 60], // SECONDS: before the same enemy gun is answered again.
        ["CBE_AIPass_CounterBattery_ShootAndScoot", true], // BOOL: mobile batteries relocate after counter-battery.
        ["CBE_AIPass_Airborne_Enable", false], // BOOL: AI passengers parachute out near known enemies.
        ["CBE_AIPass_Airborne_ApproachDistance", 2000], // METRES: climb to jump altitude inside this range.
        ["CBE_AIPass_Airborne_DeployDistance", 700], // METRES: jump inside this range of a known enemy.
        ["CBE_AIPass_Airborne_Altitude", 250], // METRES: jump altitude above ground.
        ["CBE_AIPass_Airborne_MinAltitude", 120], // METRES: never jump lower than this.
        ["CBE_AIPass_Airborne_JumpInterval", 1], // SECONDS: between jumpers.
        ["CBE_AIPass_Garrison_BreakFraction", 0.5], // 0-1: a garrison breaks at this share of its strength.
        ["CBE_Cortex_AttackRunFlares_Enable", true], // BOOL: finite countermeasure bursts approaching and leaving assigned attack targets.
        ["CBE_Cortex_AirAttack_Enable", true], // BOOL: threat-aware finite aircraft attack patterns with safe Zeus handover.
        ["CBE_AIPass_AircraftFlares_Enable", true], // BOOL: eligible AI aircraft flare at incoming missiles.
        ["CBE_AIPass_ProfileBehaviour", createHashMapFromArray [ // ADVANCED: morale/preparation per profile; legacy movement keys are compatibility-only.
            ["MILITIA", createHashMapFromArray [["flankChance", 0.3], ["assaultChance", 0.2], ["advanceChance", 0.7], ["investigateChance", 0.4], ["coordinatedChance", 0.2], ["moraleShaken", 0.65], ["moraleBroken", 0.4], ["retreatScale", 1.5], ["surrenderSurvivors", 3]]],
            ["LINE", createHashMapFromArray [["flankChance", 0.5], ["assaultChance", 0.4], ["advanceChance", 0.6], ["investigateChance", 0.6], ["coordinatedChance", 0.4], ["moraleShaken", 0.55], ["moraleBroken", 0.3], ["retreatScale", 1], ["surrenderSurvivors", 2]]],
            ["LEGACY", createHashMapFromArray [["flankChance", 0.5], ["assaultChance", 0.4], ["advanceChance", 0.6], ["investigateChance", 0.6], ["coordinatedChance", 0.4], ["moraleShaken", 0.55], ["moraleBroken", 0.3], ["retreatScale", 1], ["surrenderSurvivors", 2]]],
            ["VETERAN", createHashMapFromArray [["flankChance", 0.7], ["assaultChance", 0.55], ["advanceChance", 0.5], ["investigateChance", 0.75], ["coordinatedChance", 0.5], ["moraleShaken", 0.45], ["moraleBroken", 0.22], ["retreatScale", 0.8], ["surrenderSurvivors", 1]]],
            ["ELITE", createHashMapFromArray [["flankChance", 0.9], ["assaultChance", 0.7], ["advanceChance", 0.4], ["investigateChance", 0.85], ["coordinatedChance", 0.6], ["moraleShaken", 0.4], ["moraleBroken", 0.18], ["retreatScale", 0.7], ["surrenderSurvivors", 1]]]
        ]],
        ["CBE_AIPass_FactionProfiles", createHashMap], // MAP: CfgFactionClasses name to behaviour profile, for example OPF_F to ELITE.
        ["CBE_AIPass_ZeusHoldSeconds", 120], // SECONDS: direct Zeus edit hold; waypoint chains release when complete.
        ["CBE_AIPass_Investigate_Enable", true], // BOOL: squads check out enemies they know about but have not seen.
        ["CBE_AIPass_Investigate_Range", 300], // METRES: how far away a known enemy may be to be investigated.
        ["CBE_AIPass_Investigate_Seconds", 60], // SECONDS: investigation time limit.
        ["CBE_AIPass_Assault_Enable", true], // BOOL: paired-element clear-through after manoeuvre or directly against a fresh close threat.
        ["CBE_AIPass_Assault_Range", 80], // METRES: final-assault transition range; direct close assault is capped at 60 m.
        ["CBE_AIPass_BuildingCombat_Enable", true], // BOOL: enter a usable building containing a recent native-known hostile.
        ["CBE_AIPass_BuildingCombat_Range", 100], // METRES: maximum range for natural hostile-building entry.
        ["CBE_AIPass_Advance_Enable", true], // BOOL: pinned squads with somewhere to go push a team forward in bounds.
        ["CBE_AIPass_Advance_MinContactSeconds", 0], // SECONDS: optional confirmed-contact delay before an advance is considered.
        ["CBE_AIPass_Advance_Cooldown", 20], // SECONDS: after an advance ends before the squad may start another.
        ["CBE_AIPass_CoordinatedAssault_Enable", true], // BOOL: reinforcing squads assault together while the first squad fires.
        ["CBE_AIPass_CoordinatedAssault_MaxMovers", 2], // Per-operation concurrent mover cap; safe distinct corridors remain required.
        ["CBE_AIPass_Stance_Enable", true], // BOOL: stance chosen from the height of the cover in front.
        ["CBE_AIPass_AmmoShare_Enable", true], // BOOL: soldiers low on magazines get one from a squad-mate.
        ["CBE_AIPass_AmmoShare_Distance", 10], // METRES: how close the squad-mate must be.
        ["CBE_AIPass_AAIntercept_Enable", false], // BOOL: experimental finite native-warning main-turret response; measured same-owner direct-pass fuse only.
        ["CBE_AIPass_VehicleGunnery_Enable", true], // BOOL: gunners prioritise AT soldiers; armour keeps away from them.
        ["CBE_AIPass_Vehicles_StandoffDistance", 250], // METRES: distance armour keeps from known AT soldiers.
        ["CBE_AIPass_ArtillerySmoke_Enable", true], // BOOL: a retreating squad gets an artillery smoke screen (needs Artillery).
        ["CBE_AIPass_AircraftBreak_Enable", true], // BOOL: eligible AI aircraft jink sideways from missiles; test addon aircraft first.
        ["CBE_AI_ProfileDisplayNames", createHashMapFromArray [ // ADVANCED: labels only; keys are implementation IDs.
            ["LEGACY", "Existing Mission Balance"], ["MILITIA", "CBE Militia"],
            ["LINE", "CBE Line"], ["VETERAN", "CBE Veteran"], ["ELITE", "CBE Elite"]
        ]]
    ]]
]
