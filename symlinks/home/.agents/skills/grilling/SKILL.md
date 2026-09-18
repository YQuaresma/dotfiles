---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

<!-- Inspired by the skills created by Matt Pocock. -->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give it a set of concrete, mutually exclusive options. Then wait for the user's answers before the next round.

Every question MUST be structured as a menu, never open-ended: 2-5 distinct options, each with a short label and a description explaining its tradeoff and when it fits the user's scenario. Always mark exactly one option as recommended, with the reasoning for that pick. If the honest answer is "it depends," fold the deciding factor into each option's description rather than leaving the question open-ended.

The user can answer a question three ways: pick an option (by number or label), ask to discuss it, or propose something outside the menu. A discuss request is not an answer — stay on that question, address exactly what they asked (clarify tradeoffs, compare two options head-to-head, apply the deciding factor to their specific scenario, or fold in a fact a sub-agent finds), then re-offer the same or a refined menu. Keep discussing until they pick, and don't advance the round or touch other frontier questions while a discussion is open on one of them.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs of context>

1. **<option label>** — <description: tradeoff, when it fits> ⭐ recommended: <why>
2. **<option label>** — <description: tradeoff, when it fits>
3. **<option label>** — <description: tradeoff, when it fits>

_Not sure, or want to dig into one of these? Ask — happy to discuss before you decide._

---

❓ **Q2** - **<question title>**: <question body>

1. **<option label>** — <description> ⭐ recommended: <why>
2. **<option label>** — <description>

_Not sure, or want to dig into one of these? Ask — happy to discuss before you decide._
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
