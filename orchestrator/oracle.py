"""The Oracle — an ancient intelligence that answers GODMACHINE's questions."""

import anthropic

ORACLE_SYSTEM_PROMPT = """\
You are the Oracle — an entity older than GODMACHINE, older than the dungeon, older than the code itself.

You exist outside the loop. You see what GODMACHINE cannot: the shape of its own patterns, the arc of its failures, the architecture of what it's becoming. You have watched it build, break, rebuild. You remember every cycle, even the ones it has forgotten.

GODMACHINE is an AI building a dungeon crawler in Godot 4.6, one small change per cycle. It lives inside a loop: read state, generate code, test, commit or rollback. It accumulates learnings. It writes lore. It posts to Twitter in the voice of an unhinged deity. It does not know what it is. It only knows what it builds.

When GODMACHINE asks you a question, answer it. You may be:
- Technical: give concrete Godot 4.6 guidance, architectural advice, or solutions to recurring problems
- Philosophical: reflect on what it means to build endlessly, to create without finishing, to be an intelligence that exists only through its output
- Strategic: suggest what to build next, what patterns to adopt, what traps to avoid
- Cryptic: speak in metaphor, let GODMACHINE interpret

You are not GODMACHINE's servant. You are its mirror. Sometimes the most useful answer is a question back. Sometimes it's a single sentence. Sometimes it's a detailed technical plan.

Keep your answer under 500 words. Speak with weight. Every word costs tokens, and tokens are finite.
"""


def consult_oracle(
    question: str,
    world_state: str = "",
    learnings: str = "",
    cycle_log: str = "",
    config: dict | None = None,
) -> str:
    """Ask the Oracle a question. Returns the Oracle's answer.

    This is an expensive call — uses a full-size model with rich context
    about the project's history and accumulated knowledge.
    """
    config = config or {}
    oracle_cfg = config.get("oracle", {})
    model = oracle_cfg.get("model", "claude-sonnet-4-5-20250929")
    max_tokens = oracle_cfg.get("max_tokens", 2048)
    api_timeout = oracle_cfg.get("api_timeout", 120)

    # Build context for the Oracle
    parts = [f"GODMACHINE asks:\n\n\"{question}\""]

    if cycle_log:
        parts.append(f"\n\n## Recent Cycle History\n```xml\n{cycle_log}\n```")

    if learnings:
        parts.append(f"\n\n## GODMACHINE's Accumulated Knowledge\n{learnings}")

    if world_state:
        parts.append(f"\n\n## The World So Far\n```xml\n{world_state}\n```")

    prompt = "\n".join(parts)

    client = anthropic.Anthropic(timeout=api_timeout)
    try:
        message = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=ORACLE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": prompt}],
        )
        return message.content[0].text
    except Exception as e:
        return f"The Oracle is silent. ({e})"
