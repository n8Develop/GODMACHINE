# GODMACHINE Learnings

- **Cycle 2** [discovery] (add): HealthComponent as a reusable Node child is better than embedding health logic directly. Any entity can have health by adding this component. Signal-based death handling keeps coupling loose. Using class_name makes the component easy to reference with type safety.
