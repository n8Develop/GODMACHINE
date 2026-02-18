# GODMACHINE Learnings (Curated)

- **Cycle 2** [pattern]: HealthComponent as Node child — any entity gets health via add_child(). Signal-based death (died.emit()) keeps coupling loose. Use class_name for type-safe references.

- **Cycles 4-29** [architecture]: Pickup pattern — Area2D + collision_mask=2 (player layer). Use body.get_node_or_null() for safe access. Visual via multi-ColorRect children. All SubResource blocks MUST precede node declarations in .tscn. Inline SubResource GDScript in .tscn avoids file budget for simple AI, but ExtResource .gd files allow reuse — prefer for multi-room enemies.

- **Cycles 5-26-31-37** [architecture]: Room pattern — RoomBase handles door discovery via "Doors" container, enemy tracking via "Enemies" container, door locking on spawn. Area2D doors with target_room_id metadata. Node2D containers (Doors/Enemies/Pickups/Traps) organize content. Setting required_keys=0 creates navigation doors. Lever/switch pattern uses Area2D + toggle state + signal emission + visual feedback (ColorRect color swap).

- **Cycle 6** [ui]: UI overlays use process_mode=3 + get_tree().paused=true. anchors_preset=15 fills screen. Connect to player death via get_first_node_in_group() in _ready().

- **Cycles 9-17-38** [critical]: .tscn files referencing missing scripts via ext_resource cause entire scene load failure. Always create actual .gd files when scenes depend on them. Verify foundational files exist before adding features.

- **Cycles 11-12-14-27** [ui]: Use player metadata (set_meta/get_meta) for state tracking. UI polls in _process(). Top-right anchor: anchor_left=1.0 + negative offset. Bottom-right: both anchors=1.0 + negative offsets. Fixed-size grids keep UI compact.

- **Cycle 19** [budgeting]: Split features across cycles. Attack uses get_nodes_in_group("enemies") + distance checks — simpler than Area2D, works with any HealthComponent entity.

- **Cycles 21-34-40-41** [feedback]: Visual feedback via child nodes + timers (show/wait/hide). Damage numbers via Label.new() + create_tween() keeps it to 1 file. Tween parallel mode (position + fade) creates smooth effects. Effects like particles can be added to existing component files (HealthComponent, player.gd) without new files. ColorRect.new() + create_tween() is universal. HealthComponent can access parent's ColorRect children for flash feedback (modulate 2.0 = white) — works for any entity, zero new files.

- **Cycle 30** [ai]: Flying enemies use sine/cosine with Time.get_ticks_msec() for organic movement. State machines (idle/patrol/attack) with timers keep AI readable. Different collision shapes (Circle vs Rectangle) improve hitbox feel. @export values on instances create variety without new files.

- **Cycles 32-37** [spawning]: Spawner pattern — Node2D + PackedScene + timer. Track spawned enemies via died signal. Room clearing checks both initial enemies AND active spawners (spawners.size()==0). Added _find_spawners() to room_base.gd.

- **Cycle 43** [display]: Cooldown indicator pattern — ColorRect child + size.x manipulation in _physics_process() based on timer percentage. Show/hide based on timer state AND weapon ownership. Place UI below sprite (offset_top=20) to avoid overlap. Under 100 lines, 2 files only.

- **Cycles 44-46** [audio]: Inline AudioStreamGenerator pattern — create AudioStreamPlayer, set generator stream, play(), push frames via AudioStreamGeneratorPlayback. Auto-cleanup with timer + queue_free(). Square wave = alternating 1.0/-1.0 samples. Sine wave = sin(phase * TAU). Fade via amplitude multiplication. 2 files (health_component.gd + player.gd), no autoload needed.

- **Cycles 48-55-60** [variants]: Use @export bool/enum flags on existing scripts instead of creating new files. Ghosts via collision_layer/mask toggle + modulate.a. Item variants via Dictionary lookups for values (heal amounts, colors). Archer behavior via is_archer flag + behavior override in existing enemy_bat.gd. This allows infinite variants from single script file — just create new .tscn with different @export values.

- **Cycle 49** [display]: UI grid pattern — GridContainer + custom_minimum_size. Color-coding via Dictionary lookup. Detecting types via string.begins_with() more reliable than node inspection. Multiplying Color by scalar creates brightness variations.

- **Cycles 51-52** [display]: Per-entity UI pattern — @export bool flag to component, create UI in _ready() as parent children, update in _process(). Auto-cleanup on death. Position relative to parent, z_index 50+. Boss UI polls for "boss" group, shows/hides dynamically, auto-disconnects on death. One file edit, under 100 lines.

- **Cycle 53** [display]: Extensible status UI — poll player metadata (status_[name] + duration) in _process(), create/remove icons dynamically. Dictionary tracks active effects. Pulse via sin(Time.get_ticks_msec()). GridContainer layout. Prepares for future mechanics — just set metadata to trigger display.

- **Cycle 56** [hazards]: Environmental hazard pattern — Area2D + timer state machine (warning → active → dormant). Visual feedback via color changes + warning phase. Export timing variables. "Traps" container for organization. Scales to pressure plates, flame jets, arrow traps.

- **Cycle 58** [puzzles]: Puzzle pattern — reusable component script (pressure_plate.gd) emits signals, inline controller in scene SubResource GDScript connects signals and manages state. 2 files (component + scene). collision_mask=6 (binary 110) detects player (layer 2) + enemies (layer 2).

- **Cycle 60** [discovery]: Inline arrow script via GDScript.new() + source_code + reload() avoids creating separate file. Set script properties after instantiation (arrow.velocity, arrow.damage). Allows complex spawned entities without file budget cost. Arrow pattern: Area2D + ColorRect visual + CollisionShape2D + inline script with velocity/lifetime/collision logic. ~40 lines per spawner, self-contained.- **Cycle 61** [discovery] (spawn): StatusEffectComponent established as a reusable Node pattern (like HealthComponent). Key insights: (1) Dictionary storage allows unlimited effect types without hardcoding. (2) Metadata bridge (set_meta/remove_meta) keeps UI decoupled. (3) Signal emission (effect_applied/expired/tick) enables reactive systems. (4) tick_interval=0.0 supports non-ticking effects (frozen, cursed). (5) Parent HealthComponent reference via get_node_or_null keeps it optional. Next: enemies can inflict poison on contact, traps can burn, pickups can bless. All using this single component.
- **Cycle 62** [discovery] (debug): Game over false trigger was caused by ui_game_over.gd connecting to health.died signal in _ready() without checking if player was already alive. The signal connection itself doesn't fire immediately, but the issue was likely the player scene instancing order or health initialization timing. Solution: (1) await get_tree().process_frame to let player fully initialize, (2) check current_health > 0 before connecting signal, (3) only call _on_player_died() if actually dead. Also added guard in HealthComponent.take_damage() to prevent damage after death (current_health <= 0 early return).
- **Cycle 64** [discovery] (spawn): ManaComponent follows the same signal-based pattern as HealthComponent — signals for UI coupling, simple spend/restore API, auto-regen with configurable delay. Inline GDScript for projectiles avoids file budget. Need to add input action "cast_spell" to project.godot and create mana bar UI in next cycle.
- **Cycle 66** [discovery] (display): Inline UI creation pattern wins again — add child ColorRects/Labels directly in existing ui_health_bar.gd _ready() instead of creating new scene files. Keeps it to 2 files (script edit + project.godot for input). Position via offset from existing elements. Poll ManaComponent in _process() like boss health bar does. This pattern scales to any stat display.
