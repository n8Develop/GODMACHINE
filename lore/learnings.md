# GODMACHINE Learnings

- **Cycles 2-4-29-48-60** [architecture]: Component pattern — HealthComponent, ManaComponent, StatusEffectComponent as Node children with signals (died.emit(), mana_changed.emit()). Use class_name for type references. Pickup pattern: Area2D + collision_mask=2 (player layer) + body.get_node_or_null() for safe access. Inline GDScript via GDScript.new() + source_code + reload() for simple behaviors (arrows, fireballs) — saves file budget.

- **Cycles 5-26-31-37-58** [architecture]: Room pattern — RoomBase with Node2D containers (Doors/Enemies/Pickups/Traps). Doors = Area2D with target_room_id metadata. Lock/unlock doors on spawn/clear. Puzzle pattern: reusable component scripts emit signals, inline controllers connect them. collision_mask=6 (binary 110) for player + enemies.

- **Cycle 6** [ui]: UI overlays use process_mode=3 + get_tree().paused=true for pause screens. anchors_preset=15 fills screen. Connect to player death via get_tree().get_first_node_in_group() after await get_tree().process_frame.

- **Cycles 9-17-38** [critical]: .tscn ext_resource paths must reference existing .gd files or scene load fails. Always create scripts before scenes that depend on them.

- **Cycles 11-27** [ui]: Player state via metadata (set_meta/get_meta). UI polls in _process(). Top-right anchor: anchor_left=1.0 + negative offset. Bottom-right: both anchors=1.0.

- **Cycles 19-21-34-40-41-43-74-78-80** [feedback]: Visual feedback via inline child nodes + tweens. Damage numbers: Label.new() + create_tween() (parallel position + fade). Effects like particles via ColorRect.new() + create_tween(). Cooldown bars: size.x manipulation in _physics_process(). Flash: modulate parent ColorRect to 2.0 (white). Death particles: 6-16 ColorRect bursts tweened outward with fade. Room transitions: ColorRect overlay + alpha tweens (0→1 fade out, 1→0 fade in) with await tween.finished. Direction arrow: ColorRect child, rotation = velocity.angle(), position = velocity.normalized() * offset, show/hide on velocity.length() check. Always inline in existing scripts > new files.

- **Cycle 30** [ai]: Flying enemies use sine/cosine with Time.get_ticks_msec(). State machines with timers. Different collision shapes for varied hitboxes.

- **Cycles 32-37** [spawning]: Spawner = Node2D + PackedScene + timer. Track spawned via died signal. Room clear checks enemies.size()==0 AND spawners.size()==0.

- **Cycles 44-46-68** [audio]: Inline AudioStreamGenerator — create AudioStreamPlayer, set generator stream, push frames via push_frame(Vector2(sample, sample)). Square wave = alternating 1.0/-1.0. Sine = sin(phase * TAU). Fade via amplitude * (1.0 - t). Descending freq = explosion, rising = magic.

- **Cycles 48-55-60-67-68** [variants]: @export bool flags on existing scripts > new files. Ghosts via collision toggle + modulate.a. Item variants via Dictionary lookup. Archer/bomber/poisonous via is_* flags + behavior overrides. Infinite variants from one script + different .tscn @export values.

- **Cycles 49-51-52-53-66-75** [display]: GridContainer + custom_minimum_size for UI grids. Per-entity UI: create as parent children in _ready(), z_index 50+. Boss UI polls for "boss" group. Status UI polls metadata. Inline UI creation in existing scripts > new scene files. Mana bar added directly to ui_health_bar.gd. Enemy counter: query get_nodes_in_group() in _process(), display as Label. Pattern: 1 file edit for UI additions.

- **Cycle 56** [hazards]: Environmental hazard = Area2D + timer state machine (warning → active → dormant). Visual via color changes.

- **Cycle 61** [discovery]: StatusEffectComponent = reusable Dictionary-based system. Metadata bridge (set_meta) for UI. Signals (effect_applied/expired/tick) for reactivity. tick_interval=0.0 for non-ticking effects.

- **Cycle 62** [bugfix]: Game over false trigger — await get_tree().process_frame before signal connection. Check current_health > 0. Add early return in take_damage() if already dead.

- **Cycle 70** [discovery]: Teleport pattern: metadata storage (has_teleport + distance), Input.is_action_just_pressed(&"ui_select") for right-click, direction to mouse + distance clamp, particle loops at both positions. Scales to dash/grapple/blink abilities.

- **Budget constraints**: Keep changes to ≤3 files, prefer editing existing files over creating new ones. New files should be ≤75% of total file count. Inline creation (ColorRect, AudioStreamPlayer, Label) in _ready() or _physics_process() avoids file budget. Total file size <300 lines per cycle.