# Settings reference

Generated from `CortexTuningSpec` and `AITweaksSettingsSections`. CBA pages are numbered by use case, with enable gates before tuning. Keys, values, defaults and activation policy remain the script and persistence contract. CBA owns server enforcement and JIP synchronization. Custom profiles extend choices at runtime.

Live options follow the owner update; next-operation controls preserve committed intent. Configuration is not behavioural acceptance; see [inventory](CURRENT-INVENTORY.md).

Vehicle combat and passengers use the Vehicles page. Registered convoy travel, driving and passengers use the separate Convoys page. Convoy road assistance currently applies only to registered convoys; it is not a general driving controller.

## 01 General

### 01 Participation and ownership

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Enable` | Enable Cortex automatic tactics | CHECKBOX | true | [] | LIVE | Master control for Cortex actions and reactions. The purpose switches below choose which tactics Cortex may use; convoy control remains independent. |

### 02 Tactical profile

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_BehaviourProfile` | Behaviour profile | COMBO | "" | [["", "MILITIA", "LINE", "VETERAN", "ELITE"], ["Follow the AI Rebalance profile", "Militia", "Line", "Veteran", "Elite"]] | NEXT_OPERATION | Tactics profile for every squad without a group or faction profile of its own. Skill values are not changed. |
| `CBE_AIPass_Aggression` | Aggression | SLIDER | 1.2 | [0, 2, 2] | NEXT_OPERATION | Scales flank/advance preference, optional grenade preparation, investigation and coordinated-assault participation. Positive local preferences choose which viable manoeuvre starts instead of deciding whether the squad acts. Default 1.2 adds initiative; 1 is the profile value and 0 excludes proactive tactics. |
| `CBE_AIPass_Cohesion` | Cohesion | SLIDER | 1 | [0.5, 2, 2] | NEXT_OPERATION | How much punishment squads take before morale breaks. Above 1 they hold longer, below 1 they break sooner. |
| `CBE_AIPass_ReactionSpeed` | Reaction speed | SLIDER | 1 | [0.5, 2, 2] | NEXT_OPERATION | How often squads re-assess. Above 1 they react faster and use more server time; below 1 slower. |
| `CBE_AIPass_EngageRange` | Engagement range (m) | SLIDER | 800 | [200, 1500, 0] | NEXT_OPERATION | Known enemies within this range of a squad leader are acted on. |
| `CBE_AIPass_ZeusHoldSeconds` | Zeus direct-control hold (s) | SLIDER | 120 | [0, 600, 0] | NEXT_OPERATION | How long CBE leaves a squad alone after Zeus directly edits it or opens its attributes. Zeus waypoints own movement until their chain finishes and then release immediately. Selecting a squad for inspection does not interrupt it. |

### 03 Performance

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_TickBudgetMs` | AI work budget (ms) | SLIDER | 1 | [0.2, 5, 1] | LIVE | Soft owner-local budget for due AI jobs. A running job is never interrupted; lower values spread work across more frames. |
| `CBE_AIPass_LowFpsThreshold` | Low-FPS backoff threshold | SLIDER | 25 | [10, 50, 0] | LIVE | Below this owner-machine FPS, non-urgent behaviour jobs are rescheduled less often. |

## 02 Skills

### 01 Profiles and visibility

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIRebalance_Enable` | Apply CBE skill profiles | CHECKBOX | false | [] | LIVE | Optional skill adjustment, off by default to preserve mission skills. Later skill or aim edits yield the unit to mission control until explicitly released. |
| `CBE_AIRebalance_Mode` | Lighting | COMBO | "AUTO" | [["AUTO", "DAY", "NIGHT"], ["Automatic visibility", "Daylight override", "Low light (legacy)"]] | LIVE | Automatic follows ambient darkness and equipped night vision. Day disables the extra penalty; Low light retains the legacy night profile. |
| `CBE_AIRebalance_Profile` | Selected CBE skill profile | COMBO | "LINE" | [["LEGACY", "MILITIA", "LINE", "VETERAN", "ELITE"], ["LEGACY", "MILITIA", "LINE", "VETERAN", "ELITE"]] | LIVE | Skill values used when Apply CBE skill profiles is enabled. This is independent of the tactical behaviour profile. |

### 02 Weapon precision

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AI_InfantryDispersion` | Infantry weapon dispersion | SLIDER | 1.35 | [1, 3, 2] | LIVE | Owner-local aim coefficient for dismounted AI and vehicle cargo. Higher values reduce precision without changing reaction or movement skill. |
| `CBE_AI_VehicleCrewAimMultiplier` | Vehicle crew precision | SLIDER | 0.6 | [0.25, 1, 2] | LIVE | Final multiplier for operating vehicle and aircraft crew aiming skills. Cargo keeps the normal infantry profile. |
| `CBE_AI_VehicleCrewDispersion` | Ground vehicle dispersion | SLIDER | 3.5 | [1, 6, 2] | LIVE | Owner-local aim coefficient for ground-vehicle operators. CBE skips this layer when an external turret dispersion provider is loaded to avoid double stacking. |
| `CBE_AI_AirCrewDispersion` | Aircraft weapon dispersion | SLIDER | 4.25 | [1, 7, 2] | LIVE | Owner-local aim coefficient for aircraft operators. Precision-excluded aircraft remain exempt; external turret dispersion prevents double stacking. |

## 03 Infantry

### 01 Awareness and contact

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Contact_Enable` | Contact handling | CHECKBOX | true | [] | NEXT_OPERATION | Squads switch to combat on contact and return to their previous behaviour and waypoints afterwards. Needed by every combat option below. |
| `CBE_AIPass_PostContact_Enable` | Post-contact search | CHECKBOX | true | [] | NEXT_OPERATION | After contact is lost: hold, send two soldiers to check the last known position, regroup. |
| `CBE_AIPass_Investigate_Enable` | Investigation | CHECKBOX | true | [] | NEXT_OPERATION | Squads send two riflemen to check enemies they know about but have not seen. |
| `CBE_AIPass_Danger_Enable` | Danger response | CHECKBOX | true | [] | LIVE | Enables CBE's bounded local danger reflex and tactical group handoff. When disabled, the configured FSM exits without issuing CBE stance, movement, targeting or planning commands. |
| `CBE_AIPass_DangerEvasion_Enable` | Immediate danger evasion | CHECKBOX | true | [] | LIVE | Allows idle riflemen to use a bounded native prone roll or standing/crouched lateral dodge after a hit or near round. Known side obstructions defer upright actions. Committed movement, specialist ownership and native tasks take priority. Requires danger response. |
| `CBE_AIPass_DangerObservation_Enable` | Body and scream observation | CHECKBOX | true | [] | LIVE | Allows eligible idle infantry to glance toward body or scream positions without granting target knowledge or movement orders. Requires danger response. |
| `CBE_AIPass_DangerConcealment_Enable` | Concealment fallback | CHECKBOX | true | [] | LIVE | Allows a separate visual-screening search after solid cover fails. Concealment does not establish protection from bullets. Requires danger response. |
| `CBE_AIPass_DangerSmoke_Enable` | Danger smoke screen | CHECKBOX | true | [] | LIVE | Allows one available soldier to throw carried smoke during severe incoming danger. The operation continues without waiting for the throw. |
| `CBE_AIPass_Hearing_Enable` | Nearby gunfire investigation | CHECKBOX | true | [] | NEXT_OPERATION | Hostile FiredNear events create a throttled, approximate 50 m area for investigation, never a target reveal. |
| `CBE_AIPass_PostContact_LostSeconds` | Contact lost delay (s) | SLIDER | 30 | [3, 120, 0] | NEXT_OPERATION | Seconds without a sighting before Cortex leaves contact. Active manoeuvres finish or abort before this handover. |
| `CBE_AIPass_PostContact_SecuritySeconds` | Security hold (s) | SLIDER | 10 | [0, 60, 0] | NEXT_OPERATION | Seconds spent securing the last contact before a search team moves. |
| `CBE_AIPass_PostContact_SearchSeconds` | Search limit (s) | SLIDER | 45 | [10, 180, 0] | NEXT_OPERATION | Maximum time for the two-soldier search of the last known enemy position. |

### 02 Fire and immediate reactions

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_FireControl_Enable` | Fire control | CHECKBOX | true | [] | NEXT_OPERATION | Close threats first, spread fire across visible enemies, and alternate suppression inside each squad. A short random delay keeps separate squads from firing in lockstep; every ordered burst checks for friendlies. |
| `CBE_AIPass_GrenadeEvasion_Enable` | Grenade evasion | CHECKBOX | true | [] | LIVE | AI move away from a live grenade they can see. Test before live use. |
| `CBE_AIPass_AntiArmour_Enable` | Anti-armour | CHECKBOX | true | [] | NEXT_OPERATION | The best anti-tank gunner engages known armour, clear of backblast. |
| `CBE_AIPass_Illumination_Enable` | Infantry illumination (experimental) | CHECKBOX | false | [] | LIVE | One idle grenadier may natively load and fire a carried illumination flare in darkness. Original actor authority and a finite deadline apply; live validation pending. |
| `CBE_AIPass_StaticSupport_Enable` | Use nearby static weapons | CHECKBOX | true | [] | NEXT_OPERATION | During confirmed contact, one uncommitted nonleader may physically occupy a nearby empty friendly static weapon. The squad does not wait for the mount and a failed attempt is not retried during the same contact. |
| `CBE_AIPass_StaticDeploy_Enable` | Deploy carried static weapons | CHECKBOX | true | [] | NEXT_OPERATION | When no suitable emplacement exists, a compatible two-person weapon team may physically assemble its carried weapon and occupy the real gunner seat. The squad never waits for assembly. |
| `CBE_AIPass_FireControl_MaxShootersPerTarget` | Shooters per target | SLIDER | 2 | [1, 12, 0] | NEXT_OPERATION | Extra shooters prefer another visible enemy once this many soldiers are assigned to one target. Immediate close threats still take priority. |
| `CBE_AIPass_FireControl_MaxSuppressors` | Simultaneous suppressors | SLIDER | 2 | [1, 8, 0] | NEXT_OPERATION | Maximum soldiers assigned suppression simultaneously. |

### 03 Manoeuvre

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Flank_Enable` | Flanking | CHECKBOX | true | [] | NEXT_OPERATION | Half the squad flanks in covered bounds while the rest suppresses. |
| `CBE_AIPass_StreetCrossing_Enable` | Street crossing | CHECKBOX | true | [] | NEXT_OPERATION | Flanking squads stop at roads, throw smoke and cross in one bound. |
| `CBE_AIPass_Assault_Enable` | Final assault | CHECKBOX | true | [] | NEXT_OPERATION | An eligible manoeuvre finishes with a paired-element clear-through; a fresh known threat already inside ordinary manoeuvre range can start it directly. |
| `CBE_AIPass_Advance_Enable` | Bounding advance | CHECKBOX | true | [] | NEXT_OPERATION | Squads in a long firefight push a fire team towards their waypoint in covered bounds. |
| `CBE_AIPass_Advance_MinContactSeconds` | Advance contact delay | SLIDER | 0 | [0, 300, 0] | NEXT_OPERATION | Optional seconds of confirmed contact before a bounding advance may begin. The default is zero because knowledge, morale, range, actor and avenue checks already decide whether the manoeuvre is viable. |
| `CBE_AIPass_Advance_Cooldown` | Advance repeat delay | SLIDER | 20 | [0, 180, 0] | NEXT_OPERATION | Seconds after an advance ends before the same squad may start another. This is shorter than the flank delay so a squad can continue progressing in successive tactical bounds without immediately restarting a finished drill. |
| `CBE_AIPass_Flank_MaxRange` | Flank range (m) | SLIDER | 400 | [100, 800, 0] | NEXT_OPERATION | Enemies farther than this are not flanked. |
| `CBE_AIPass_Flank_MinGroupSize` | Minimum flanking squad size | SLIDER | 6 | [2, 16, 0] | NEXT_OPERATION | Capable soldiers on foot required to split movement and support elements. |
| `CBE_AIPass_Flank_MinRange` | Minimum flank range (m) | SLIDER | 60 | [20, 200, 0] | NEXT_OPERATION | Nearer contacts are engaged without opening a flank route. |
| `CBE_AIPass_Flank_BoundDistance` | Flank bound distance (m) | SLIDER | 55 | [15, 100, 0] | NEXT_OPERATION | Intended distance of a covered bound; actual terrain may shorten it. |
| `CBE_AIPass_Flank_BoundPause` | Optional overwatch interval (s) | SLIDER | 0 | [0, 10, 1] | NEXT_OPERATION | Optional deliberate halt after physical arrival. Zero keeps bounds and assault handoffs continuous; smoke and grenade actions never extend it. |
| `CBE_AIPass_Flank_BoundTimeout` | Bound no-progress limit (s) | SLIDER | 25 | [5, 60, 0] | NEXT_OPERATION | No-progress limit for a bound; reaching the limit never counts as arrival. |
| `CBE_AIPass_Flank_Cooldown` | Flank retry cooldown (s) | SLIDER | 90 | [10, 300, 0] | NEXT_OPERATION | Minimum interval before the same squad starts another flank. |

### 04 Cover and stance

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Stance_Enable` | Stance from cover | CHECKBOX | true | [] | NEXT_OPERATION | Soldiers stand, kneel or go prone to match the cover in front of them. |
| `CBE_AIPass_CoverValidation_Enable` | Additional cover checks | CHECKBOX | true | [] | NEXT_OPERATION | Adds bounded slope and body clearance checks to shared cover selection. |

### 05 Morale and withdrawal

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Morale_Enable` | Morale and retreat | CHECKBOX | true | [] | NEXT_OPERATION | Squads under heavy losses and fire break and fall back under smoke. |
| `CBE_AIPass_Surrender_Enable` | Surrender | CHECKBOX | true | [] | NEXT_OPERATION | One or two broken survivors surrender only when an enemy was observed within the last 30 seconds and is believed within 60 m, and no friendly squad is within 300 m (ACE Captives when loaded). |
| `CBE_AIPass_Morale_RetreatDistance` | Retreat distance (m) | SLIDER | 200 | [50, 500, 0] | NEXT_OPERATION | How far a broken squad falls back. |

### 06 Survivor recovery

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Regroup_Enable` | Survivor regroup | CHECKBOX | true | [] | NEXT_OPERATION | Survivors of a destroyed squad walk to and join a nearby friendly squad. |
| `CBE_AIPass_MedicalAssist_Enable` | Medical assistance | CHECKBOX | true | [] | NEXT_OPERATION | During CALM or SECURITY, one local medic physically treats a hurt squad-mate using native AI treatment. It yields to Zeus, direct orders and an active medical controller. |
| `CBE_AIPass_PostContact_RegroupSeconds` | Regroup limit (s) | SLIDER | 30 | [10, 120, 0] | NEXT_OPERATION | Maximum time for surviving squad members to close up before Cortex releases control. |
| `CBE_AIPass_Regroup_MaxRemnantSize` | Remnant size | SLIDER | 2 | [1, 8, 0] | NEXT_OPERATION | Maximum surviving members eligible for remnant recovery. |
| `CBE_AIPass_MedicalAssist_Range` | Medical selection range (m) | SLIDER | 80 | [10, 200, 0] | NEXT_OPERATION | Maximum local medic-to-casualty distance considered for one finite assistance attempt. |
| `CBE_AIPass_MedicalAssist_DamageThreshold` | Medical damage threshold | SLIDER | 0.35 | [0.1, 0.9, 2] | NEXT_OPERATION | Minimum engine damage before CBE considers vanilla medical assistance. |
| `CBE_AIPass_MedicalAssist_Timeout` | Medical attempt limit (s) | SLIDER | 45 | [10, 120, 0] | NEXT_OPERATION | Maximum duration of one native treatment attempt before CBE releases it without altering health. |
| `CBE_AIPass_Regroup_MinimumPeakSize` | Minimum previous squad size | SLIDER | 3 | [2, 16, 0] | NEXT_OPERATION | Protects deliberately small teams from automatic merging. |
| `CBE_AIPass_Regroup_SearchRadius` | Recovery host search (m) | SLIDER | 400 | [50, 1000, 0] | NEXT_OPERATION | Search radius for a compatible friendly host squad. |
| `CBE_AIPass_Regroup_MaxGroupSize` | Recovery host size limit | SLIDER | 12 | [4, 24, 0] | NEXT_OPERATION | Maximum host membership after a physical survivor merge. |
| `CBE_AIPass_Regroup_JoinDistance` | Recovery join distance (m) | SLIDER | 30 | [5, 60, 0] | NEXT_OPERATION | Survivors must reach the host before joining. |
| `CBE_AIPass_Regroup_StuckSeconds` | Recovery no-progress limit (s) | SLIDER | 20 | [5, 60, 0] | NEXT_OPERATION | Retry an isolated survivor after this interval without progress; never remotely merge it. |
| `CBE_AIPass_Regroup_TimeoutSeconds` | Recovery time limit (s) | SLIDER | 120 | [30, 300, 0] | NEXT_OPERATION | Maximum recovery attempt duration before explicit abandonment. |
| `CBE_AIPass_Regroup_SettleSeconds` | Casualty assessment delay (s) | SLIDER | 5 | [0, 15, 1] | NEXT_OPERATION | Brief delay to assess simultaneous casualties before survivor recovery. |

### 07 Buildings and CQB

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_BuildingCombat_Enable` | Enter hostile buildings | CHECKBOX | true | [] | NEXT_OPERATION | A squad of at least four may turn a recent, engine-confirmed hostile physically inside a usable building into a clearance operation. Approximate danger and outdoor contacts never trigger entry. |
| `CBE_AIPass_BuildingCombat_Range` | Hostile building entry range (m) | SLIDER | 100 | [25, 200, 0] | NEXT_OPERATION | Maximum distance for natural entry against a recently seen hostile inside a building. Explicit Clear Building orders are unaffected. |

## 04 Coordination

### 01 Communication

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_ContactReports_Enable` | Contact reports | CHECKBOX | true | [] | NEXT_OPERATION | Squads share sighted enemies by radio (blocked by jamming) or by voice. |
| `CBE_AIPass_ContactReports_Radius` | Radio report range (m) | SLIDER | 500 | [0, 1500, 0] | NEXT_OPERATION | How far squads pass sightings by radio. |

### 02 Support and assault

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Reinforce_Enable` | Reinforcement | CHECKBOX | true | [] | NEXT_OPERATION | Idle nearby squads move up behind a squad in contact. |
| `CBE_AIPass_CoordinatedAssault_Enable` | Coordinated assault | CHECKBOX | true | [] | NEXT_OPERATION | Reinforcing squads assault from both sides while the squad in contact fires. |
| `CBE_AIPass_CoordinatedAssault_MaxMovers` | Concurrent manoeuvre squads | SLIDER | 2 | [1, 4, 0] | NEXT_OPERATION | Maximum simultaneous manoeuvre elements in one communicating support opportunity. Distinct safe corridors are still required; the requester supplies support. Higher values increase planning work. Captured when the assault begins. |
| `CBE_Cortex_CombinedArms_AirRange` | Aircraft support range (m) | SLIDER | 4000 | [500, 10000, 0] | NEXT_OPERATION | How far a radio-linked aircraft may accept a fresh combined-arms opportunity. This is independent of the shorter squad report radius. |
| `CBE_AIPass_Reinforce_Radius` | Reinforcement radius (m) | SLIDER | 600 | [100, 2000, 0] | NEXT_OPERATION | How far away idle squads may be sent to help. |
| `CBE_AIPass_Reinforce_MaxResponders` | Reinforcing squads | SLIDER | 2 | [0, 5, 0] | NEXT_OPERATION | Squads sent to help one squad in contact. |

### 03 Resupply

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_CasualtyEquipment_Enable` | Casualty weapon recovery | CHECKBOX | false | [] | NEXT_OPERATION | At a verified own-group casualty visit, recover one loaded rifle or launcher into an empty slot. Never replaces existing weapons. Opt-in because this can change an intentionally unarmed role. |
| `CBE_AIPass_AmmoShare_Enable` | Ammo sharing | CHECKBOX | true | [] | NEXT_OPERATION | Soldiers down to their last magazine get one from a nearby squad-mate. |

## 05 Vehicles

### 01 General driving and route safety

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_DrivingAssist_Enable` | General driving assist | CHECKBOX | true | [] | NEXT_OPERATION | Ordinary AI ground vehicles following an existing waypoint: bounded traffic, terrain and obstacle safety, finite static-obstacle bypass, navigation-area passage and native-route recovery. Newer orders and external controllers take priority. It does not create authored waypoints, move vehicles through physics or change collision. Experimental automatic road passing is separately opt-in; cooperative traffic jam initiation is separately opt-in and unvalidated. Convoy driving is configured separately. |
| `CBE_AIPass_DrivingAssist_Passing_Enable` | Experimental automatic road passing | CHECKBOX | false | [] | LIVE | Opt-in automatic admission after sustained slow traffic. Preserves extra pull-out headway through the existing speed controller while qualifying. Uses finite geometry preparation and real owner consent before the existing driving FSM may pass. Default off: physical steering, interruption and frame-budget validation remain outstanding. Does not resolve head-on jams or change collision. Disabling stops new preparation; an admitted pass retains its finite safety/handback rules. |
| `CBE_AIPass_DrivingAssist_Queue_Enable` | Experimental automatic traffic jam recovery | CHECKBOX | false | [] | LIVE | Default off. Allows this group to initiate one cooperative queue attempt after sustained stationary head-on or qualifying crossing traffic, within its original recovery budget. Other participants must consent through their physical-recovery policy. Uses existing native reverse and crossing control; no physics push or collision changes. Disabling stops uncommitted initiation; admitted movement keeps finite safety and handback. Physical reliability and cost remain unvalidated. |
| `CBE_AIPass_DrivingAssist_CloseGates_Enable` | Experimental gate closure after passage | CHECKBOX | false | [] | LIVE | Default off. Observe actual passage of the vehicle that opened a supported gate, then request closure only for its opened leaves while nearby traffic is clear. Original120s observation limit; changed orders, ownership, locks or gate pose cancel. Sampled clearance is not continuous collision protection. |
| `CBE_AIPass_DrivingAssist_Recovery_Enable` | Physical route recovery | CHECKBOX | true | [] | LIVE | Allows finite native-route refresh and checked rear recovery for ordinary driving. Disabling prevents new attempts without cancelling an already issued native movement leg. No teleportation or collision changes. |
| `CBE_AIPass_DrivingAssist_MaxSpeed` | Maximum safety speed | SLIDER | 70 | [15, 120, 0] | LIVE | Ordinary driving safety cap in km/h. Terrain may reduce it further; a lower authored forced-speed cap is preserved. Convoys use their own speed setting. |

### 02 Combat and withdrawal

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Vehicles_Enable` | Enable Cortex vehicle tactics | CHECKBOX | true | [] | NEXT_OPERATION | Parent control for Cortex passenger dismount, remount and damaged-vehicle withdrawal. Convoy route control remains independent. |
| `CBE_AIPass_AAIntercept_Enable` | Experimental AA point-defence fire | CHECKBOX | false | [] | NEXT_OPERATION | Native warned missiles can receive a finite main-turret bullet response and measured same-owner direct-pass fuse effect. Cross-owner and submunition payloads are unsupported; physical validation remains incomplete. Off by default. |
| `CBE_AIPass_VehicleGunnery_Enable` | Vehicle gunnery | CHECKBOX | true | [] | NEXT_OPERATION | Armed crews make one safe immediate suppression response to a known danger source, then engage AT soldiers first, armour second and preserve distance from AT teams. |
| `CBE_AIPass_VehicleWithdraw_Enable` | Damage: withdraw mobile vehicle | CHECKBOX | true | [] | NEXT_OPERATION | Under Enable Cortex vehicle tactics, allows a damaged mobile vehicle to withdraw and use existing smoke. |
| `CBE_AIPass_VehicleReverse_Enable` | Withdrawal: tracked reverse leg | CHECKBOX | true | [] | LIVE | Under damaged vehicle withdrawal, tracked armour attempts a short threat-facing reverse before native escape. Disabling releases the reverse command and retains the escape route. Wheeled vehicles retain forward escape. |
| `CBE_AIPass_VehicleJink_Enable` | Danger: short vehicle escape | CHECKBOX | true | [] | NEXT_OPERATION | Allows one intact crewed fighting vehicle to make a short terrain-checked escape from a close hostile, hit or explosion. Convoys, passenger loads and existing movement owners are excluded. |
| `CBE_AIPass_VehicleReverse_Distance` | Tracked reverse distance (m) | SLIDER | 30 | [10, 60, 0] | NEXT_OPERATION | Distance away from the saved threat required before native forward escape. Captured when a reverse leg starts; its rear route is validated once. |
| `CBE_AIPass_VehicleReverse_Timeout` | Tracked reverse time limit (s) | SLIDER | 20 | [5, 45, 0] | NEXT_OPERATION | Maximum duration of one reverse attempt before finite native escape fallback. Captured when the leg starts; rear obstruction and no-progress checks remain active. |
| `CBE_AIPass_VehicleReverse_FacingTolerance` | Tracked reverse hull tolerance (degrees) | SLIDER | 35 | [10, 60, 0] | NEXT_OPERATION | Maximum angular separation between the hull front and saved contact direction for entry and completion. Captured per reverse leg; steering deadband remains inside this limit. |

### 03 Passengers

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_VehicleDismount_Enable` | Contact: dismount passengers | CHECKBOX | true | [] | NEXT_OPERATION | Under Enable Cortex vehicle tactics, unloads capable passengers only when safely stopped on dry ground. |
| `CBE_AIPass_VehicleRemount_Enable` | Contact: remount released passengers | CHECKBOX | true | [] | NEXT_OPERATION | Under Enable Cortex vehicle tactics, allows safe conscious passengers to reboard after contact. A newer Zeus order cancels remount intent. |

## 06 Convoys

### 01 Travel and spacing

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_Convoy_DefaultSpeed` | Convoy: default maximum speed (km/h) | SLIDER | 30 | [5, 120, 0] | NEXT_OPERATION | New native Zeus convoy orders use this speed; existing convoys retain their selected settings. |
| `CBE_Convoy_DefaultSeparation` | Convoy: default separation (m) | SLIDER | 30 | [10, 100, 0] | NEXT_OPERATION | New convoy centre spacing; vehicle length may increase the minimum. Applies to new orders. |
| `CBE_Convoy_DefaultPushThrough` | Convoy: default push through contact | CHECKBOX | true | [] | NEXT_OPERATION | New convoys continue through contact unless pinned. Off requests a contact halt and cargo dismount. |

### 02 Driving and route safety

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_Convoy_AvoidInfantry_Enable` | Convoy infantry avoidance | CHECKBOX | false | [] | NEXT_OPERATION | Registered convoys only: short-range friendly-infantry corridor checks before driving. Does not enable general vehicle driving assistance. |
| `CBE_Convoy_DrivingAssist_Enable` | Convoy driving assist | CHECKBOX | true | [] | NEXT_OPERATION | Registered convoys only: road look-ahead, damped speed changes and bounded forward-lane vehicle observations. Unrelated traffic can constrain every convoy vehicle without replacing predecessor spacing, bypassing obstacles or authored routes. |
| `CBE_Convoy_RouteRecovery_Enable` | Convoy route recovery | CHECKBOX | true | [] | NEXT_OPERATION | Re-selects the same unchanged final MOVE waypoint when the engine completes it more than 75 m early. It never creates a route, teleports, repairs or defeats an obstruction. |

### 03 Contact and passengers

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_Convoy_MountedFire_Enable` | Convoy mounted targeting | CHECKBOX | true | [] | NEXT_OPERATION | Registered convoys only: assigns weapon-crew targets under existing ROE. Independent of general vehicle gunnery. |
| `CBE_Convoy_Cover_Enable` | Convoy dismount movement | CHECKBOX | true | [] | NEXT_OPERATION | Moves dismounted passengers clear of vehicles; seeks cover during contact. |
| `CBE_Convoy_ContactHalt_Enable` | Convoy contact halts | CHECKBOX | true | [] | NEXT_OPERATION | Automatic ambush halt using push-through and pinned rules. Route arrival and explicit stop remain available. |
| `CBE_Convoy_Unload_Enable` | Convoy cargo unloading | CHECKBOX | true | [] | NEXT_OPERATION | Registered convoys only: unloads cargo on halt. Operating crews remain aboard; general passenger remount settings do not initiate convoy reboarding. |

## 07 Aircraft

### 01 Combat

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_Cortex_AirAttack_Enable` | Adaptive aircraft attack patterns | CHECKBOX | true | [] | NEXT_OPERATION | Eligible planes choose finite strafe, offset, hook or standoff runs. Helicopters also use hover-capable standoff and lateral gun runs. Observed AA and live weapons influence the choice; Zeus orders immediately take priority. |

### 02 Countermeasures

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_Cortex_AttackRunFlares_Enable` | Proactive attack-run countermeasures | CHECKBOX | true | [] | NEXT_OPERATION | AI aircraft expend countermeasures while approaching and leaving an assigned hostile target. This is based on attack-run geometry, not a detected missile. |
| `CBE_AIPass_AircraftFlares_Enable` | Missile-threat countermeasures | CHECKBOX | true | [] | NEXT_OPERATION | Eligible AI aircraft expend a staggered countermeasure sequence after an incoming missile is detected. |
| `CBE_AIPass_AircraftBreak_Enable` | Aircraft break-away | CHECKBOX | true | [] | NEXT_OPERATION | Eligible AI aircraft preserve forward energy while jinking away from missile launches. Test addon aircraft first. |

### 03 Landing

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_ImprovedHelicopterLanding_Enable` | Improved helicopter landing | CHECKBOX | true | [] | LIVE | Uses terrain-aware approach, flare, touchdown and go-around assistance for eligible local AI helicopter pilots. |
| `CBE_ImprovedHelicopterLanding_TriggerDistance` | Landing acquisition range (m) | SLIDER | 500 | [100, 1500, 0] | NEXT_OPERATION | Landing assistance may acquire an eligible approach within this range. |
| `CBE_ImprovedHelicopterLanding_TransitAltitude` | Landing approach altitude (m) | SLIDER | 30 | [15, 150, 0] | NEXT_OPERATION | Clear-terrain approach height; terrain and canopy safety still apply. |
| `CBE_ImprovedHelicopterLanding_GlideSlopeRatio` | Landing glide ratio | SLIDER | 4 | [2, 10, 1] | NEXT_OPERATION | Horizontal approach distance per metre of descent. |
| `CBE_ImprovedHelicopterLanding_MaximumClimbRate` | Landing climb limit (m/s) | SLIDER | 8 | [2, 15, 1] | NEXT_OPERATION | Maximum commanded climb during assisted landing. |
| `CBE_ImprovedHelicopterLanding_MaximumDescentRate` | Landing descent limit (m/s) | SLIDER | 10 | [2, 15, 1] | NEXT_OPERATION | Maximum commanded descent during assisted landing. |
| `CBE_ImprovedHelicopterLanding_MaximumGoArounds` | Landing retry limit | SLIDER | 1 | [0, 3, 0] | NEXT_OPERATION | Maximum automatic go-arounds for one landing order. |
| `CBE_ImprovedHelicopterLanding_TouchdownRadius` | Touchdown tolerance (m) | SLIDER | 5 | [2, 15, 1] | NEXT_OPERATION | Horizontal acceptance radius for touchdown. |
| `CBE_ImprovedHelicopterLanding_TouchdownHoldSeconds` | Touchdown hold (s) | SLIDER | 20 | [0, 60, 0] | NEXT_OPERATION | Hold after touchdown before releasing flight control. |

### 04 Braking

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_HelicopterDeceleration_Enable` | Helicopter deceleration correction | CHECKBOX | false | [] | LIVE | Suppresses excessive climb during aggressive AI braking while retaining terrain clearance. Disabled by default pending airframe validation. |
| `CBE_HelicopterDeceleration_MinimumSpeed` | Braking detection speed (km/h) | SLIDER | 80 | [40, 200, 0] | NEXT_OPERATION | Ignore climb corrections below this airspeed. |
| `CBE_HelicopterDeceleration_TerrainClearance` | Braking terrain clearance (m) | SLIDER | 25 | [15, 100, 0] | NEXT_OPERATION | Required clearance over sampled terrain ahead. |
| `CBE_HelicopterDeceleration_MaximumCorrectionSeconds` | Braking correction duration (s) | SLIDER | 4 | [1, 8, 1] | NEXT_OPERATION | Finite correction cap before native control resumes. |

### 05 Airborne delivery

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Airborne_Enable` | Airborne insertion | CHECKBOX | false | [] | NEXT_OPERATION | AI squads riding in AI-flown helicopters or planes parachute out when their aircraft nears a known enemy. |
| `CBE_AIPass_Airborne_DeployDistance` | Airborne: jump distance (m) | SLIDER | 700 | [200, 2000, 0] | NEXT_OPERATION | AI passengers jump when their aircraft is this close to a known enemy. |
| `CBE_AIPass_Airborne_Altitude` | Airborne: jump altitude (m) | SLIDER | 250 | [150, 600, 0] | NEXT_OPERATION | Height the aircraft climbs to for the drop. |
| `CBE_AIPass_Airborne_MinAltitude` | Airborne: lowest jump (m) | SLIDER | 120 | [80, 300, 0] | NEXT_OPERATION | Never jump lower than this. |

## 08 Support and civilians

### 01 Artillery

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_Artillery_Enable` | Enable spotter artillery support | CHECKBOX | false | [] | NEXT_OPERATION | Parent control for spotter-requested support and retreat smoke missions. Explicitly assign a spotter and configure a friendly battery first. |
| `CBE_AIPass_ArtillerySmoke_Enable` | Retreat artillery smoke mission | CHECKBOX | true | [] | NEXT_OPERATION | Allows a retreating squad to request a non-lethal smoke screen. Requires Enable spotter artillery support and an eligible battery. |
| `CBE_AIPass_Artillery_Bursts` | Burst limit | SLIDER | 3 | [1, 5, 0] | NEXT_OPERATION | Maximum HE bursts per mission; smoke uses one burst. |
| `CBE_AIPass_Artillery_RoundInterval` | Within-burst interval (s) | SLIDER | 2 | [1, 15, 0] | NEXT_OPERATION | Minimum seconds between confirmed rounds inside one burst. |
| `CBE_AIPass_Artillery_LocationResetDistance` | New location distance (m) | SLIDER | 150 | [50, 500, 0] | NEXT_OPERATION | Reported movement in metres that resets opening offset and safety checks. |
| `CBE_AIPass_Artillery_Rounds` | Support: rounds per burst | SLIDER | 3 | [1, 10, 0] | NEXT_OPERATION | Rounds in each support burst. The burst limit caps the mission. |
| `CBE_AIPass_Artillery_MaxError` | Support: accuracy needed (m) | SLIDER | 50 | [10, 200, 0] | NEXT_OPERATION | Largest target position error a squad may call fire on. Lower means fewer, more accurate missions. |
| `CBE_AIPass_Artillery_Cooldown` | Support: cooldown (s) | SLIDER | 120 | [30, 600, 0] | NEXT_OPERATION | Cooldown after a finite support mission ends. |
| `CBE_AIPass_Artillery_MinFriendlyDistance` | Support: safety distance (m) | SLIDER | 200 | [50, 500, 0] | NEXT_OPERATION | No mission lands this close to friendlies or civilians. |
| `CBE_AIPass_Artillery_ShootAndScoot` | Support: shoot and scoot | CHECKBOX | true | [] | NEXT_OPERATION | Mobile guns move after a support mission. |
| `CBE_AIPass_Artillery_DefaultRole` | Default battery role | COMBO | "BOTH" | [["BOTH", "SUPPORT", "COUNTER"], ["Support and counter-battery", "Support only", "Counter-battery only"]] | NEXT_OPERATION | Missions taken by guns without a role of their own. |
| `CBE_AIPass_Artillery_OpeningSafeDistance` | Opening safety distance (m) | SLIDER | 200 | [100, 500, 0] | NEXT_OPERATION | Minimum commanded opening aim distance from the reported target and living players. Player positions are rejection-only. |
| `CBE_AIPass_Artillery_OpeningBuffer` | Opening extra buffer (m) | SLIDER | 100 | [50, 300, 0] | NEXT_OPERATION | Additional room for ballistic spread and player movement. Live shells are not a guarantee of harmless impacts. |
| `CBE_AIPass_Artillery_WarningInterval` | Ranging warning interval (s) | SLIDER | 20 | [10, 60, 0] | NEXT_OPERATION | Minimum pause after estimated impact before the next burst. |

### 02 Counter-battery

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_CounterBattery_Enable` | Counter-battery | CHECKBOX | false | [] | NEXT_OPERATION | AI artillery answers enemy artillery whose position is known. |
| `CBE_AIPass_CounterBattery_RadarDelay` | Counter-battery: radar delay (s) | SLIDER | 20 | [1, 120, 0] | NEXT_OPERATION | Counter-battery acquisition seconds with radar coverage; capped by the normal delay. |
| `CBE_AIPass_CounterBattery_Rounds` | Counter-battery: rounds per burst | SLIDER | 4 | [1, 10, 0] | NEXT_OPERATION | Rounds in each counter-battery burst; ranging changes between bursts. |
| `CBE_AIPass_CounterBattery_Delay` | Counter-battery: delay (s) | SLIDER | 60 | [1, 120, 0] | NEXT_OPERATION | Acquisition delay without radar. Radar can shorten it. |
| `CBE_AIPass_CounterBattery_Interval` | Counter-battery: interval (s) | SLIDER | 60 | [10, 600, 0] | NEXT_OPERATION | Cooldown after the finite response ends; a new firing event is needed. |
| `CBE_AIPass_CounterBattery_MinFriendlyDistance` | Counter-battery: safety distance (m) | SLIDER | 200 | [50, 500, 0] | NEXT_OPERATION | No fire back when friendlies or civilians are this close to the enemy gun. |
| `CBE_AIPass_CounterBattery_ShootAndScoot` | Counter-battery: shoot and scoot | CHECKBOX | true | [] | NEXT_OPERATION | Mobile guns move after a counter-battery mission. |

### 03 Naval delivery

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_NavalAssault_Enable` | Naval infantry landing | CHECKBOX | true | [] | NEXT_OPERATION | AI boat crews make one finite shallow-water approach and deliver embarked infantry onto dry ground. Player, Zeus and neutral external-control ownership take priority. |

### 04 Civilian reactions

| Variable | Label | Type | Default | Range / choices | Activation | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| `CBE_AIPass_CivilianReaction_Enable` | Civilian danger reactions | CHECKBOX | true | [] | LIVE | Unarmed civilians flee nearby gunfire, explosions or a hit through one priority-aware finite response. Stronger danger can replace weaker noise; player, Zeus and neutral external-control ownership still take precedence. |
| `CBE_AIPass_CivilianReaction_Radius` | Civilian gunfire radius (m) | SLIDER | 45 | [10, 150, 0] | NEXT_OPERATION | FiredNear events inside this distance may trigger an escape response. |
| `CBE_AIPass_CivilianReaction_Distance` | Civilian escape distance (m) | SLIDER | 180 | [50, 500, 0] | NEXT_OPERATION | Approximate length of the safe escape leg away from the threat. |
| `CBE_AIPass_CivilianReaction_Cooldown` | Civilian reaction cooldown (s) | SLIDER | 20 | [2, 120, 0] | NEXT_OPERATION | Minimum delay before an equal or weaker danger event can replace the current escape order. A stronger event may replace it immediately. |
