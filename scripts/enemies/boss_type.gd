class_name BossType
extends EnemyType
## Boss-specific values. Base values such as health, speed and size come from EnemyType.
## New boss = new .tres under resources/bosses.

@export_group("Special Attacks")
## Time between special attacks (s).
@export var special_interval := 4.0
@export var slam_damage := 30.0
@export var slam_radius := 5.0
## Warning time before a ground slam.
@export var slam_windup := 1.0
@export var charge_damage := 25.0
@export var charge_distance := 14.0
@export var charge_speed := 20.0
## Warning time before a charge.
@export var charge_windup := 0.9
## Skeletons summoned on every third special attack; 0 means no summons.
@export var summon_count := 0

@export_group("Rewards")
@export var gold_reward := 100
## A mini-boss core is run loot (yours if you escape); the final boss's core is secured at once.
@export var core_reward := 1
## When the final boss dies, its core is secured and the final gate opens.
@export var is_final := false
