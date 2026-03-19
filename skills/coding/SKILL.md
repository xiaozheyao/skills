---
name: coding
description: Cross-model review workflows for code and plans. Use when the user wants Codex CLI to adversarially review artifacts produced by Claude Code, creating a structured review loop with human-in-the-loop escalation.
---

# Coding Skill

This skill covers cross-model review workflows where OpenAI Codex CLI acts as an adversarial reviewer for artifacts produced by Claude Code. Both models engage in a structured loop — Codex critiques, Claude Code evaluates, valid fixes are applied, disagreements are escalated to the user — until approval or a round cap is reached.

| Task | Document |
|------|----------|
| Reviewing a markdown plan | `${CLAUDE_PLUGIN_ROOT}/skills/coding/plan.md` |
| Reviewing code written by Claude Code | `${CLAUDE_PLUGIN_ROOT}/skills/coding/code.md` |

---

## Critical rules (read before anything else)

1. **Never blindly accept Codex feedback.** Claude Code independently evaluates
   every finding. Codex is a reviewer, not an authority.

2. **Human-in-the-loop for disagreements.** When Claude Code and Codex disagree
   on a finding, the user decides. Never silently ignore or silently accept a
   disputed finding.

3. **Full audit trail.** Every decision — accepted, rejected, or partially
   accepted — is logged with reasoning in the review log. No silent changes.

4. **Bounded loops.** Hard cap at 10 rounds prevents infinite back-and-forth.
   If approval isn't reached, surface remaining concerns to the user.

5. **Scope discipline.** Do not modify artifacts outside the agreed review scope
   without explicit user approval.

6. **Subagent isolation.** Each review round runs inside a subagent to keep the
   main conversation context clean.

7. **Prior context carries forward.** Every resubmission includes the full
   decision history so Codex can engage in genuine cross-model discussion
   rather than repeating rejected suggestions.

---

## What to read for each task

### Reviewing a plan

Read: `${CLAUDE_PLUGIN_ROOT}/skills/coding/plan.md`
- Locate or receive a markdown plan file
- Codex reviews for logical gaps, ambiguity, feasibility, internal consistency
- Structured finding format with severity levels
- Evaluate → apply / escalate → resubmit loop

### Reviewing code

Read: `${CLAUDE_PLUGIN_ROOT}/skills/coding/code.md`
- Identify code scope: files, diffs, or modules
- Codex reviews for bugs, security, performance, error handling, style, testing
- Findings include category, file, and line-level location
- Same evaluate → apply / escalate → resubmit loop
- Additional edge cases: large diffs, missing tests, out-of-scope refactoring

---

## Prerequisites

- `codex` CLI installed and authenticated (`npm install -g @openai/codex`)
- Artifacts to review must be accessible in the working directory

---

## Configuration (shared defaults)

| Parameter           | Default                    | Description                                    |
| ------------------- | -------------------------- | ---------------------------------------------- |
| `max-rounds`        | 10                         | Maximum review-revision cycles                 |
| `severity-filter`   | all                        | Review all severities, or only CRITICAL+MAJOR  |
| `auto-accept-minor` | false                      | Auto-apply MINOR findings without confirmation |
| `workspace`         | `./codex-review-workspace` | Directory for review artifacts                 |
