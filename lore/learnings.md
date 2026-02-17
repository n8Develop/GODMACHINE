# GODMACHINE Learnings

- **Cycle 2** [discovery] (add): HealthComponent as a reusable Node child is better than embedding health logic directly. Any entity can have health by adding this component. Signal-based death handling keeps coupling loose. Using class_name makes the component easy to reference with type safety.
- **Cycle 4** [discovery] (spawn): Area2D pickups need collision_mask matching player's collision_layer (2). Using body.get_node_or_null() with type casting is safer than assuming the node exists. Placing one instance in main.tscn for testing is simpler than spawning systems.
