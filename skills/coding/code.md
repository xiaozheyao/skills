# Codex Code Reviewer

## Purpose

Use OpenAI Codex CLI as an adversarial reviewer for code written by Claude Code. The two models engage in a structured review loop: Codex critiques the code, Claude Code evaluates each piece of feedback, applies what's valid, escalates disagreements to the user, and resubmits until Codex approves — or the loop cap is reached.

This creates a cross-model checks-and-balances system where neither model operates unchecked.

## Prerequisites

- `codex` CLI installed and authenticated (`npm install -g @openai/codex` or equivalent)
- The code to review must be accessible in the working directory or a provided path
- Code changes should be committed or staged so diffs are available

Before starting, verify codex is available:

```bash
command -v codex >/dev/null 2>&1 || { echo "ERROR: codex CLI not found. Install with: npm install -g @openai/codex"; exit 1; }
```

## Workflow

### Step 0: Identify the Code to Review

Determine the scope of the review. It could be:

- Explicitly provided by the user: "review `src/auth.py`"
- A set of files Claude Code just wrote or modified in the current session
- All changes since a base commit: `git diff <base>..HEAD`
- A specific directory or module

Gather the review payload:

1. **Single file or file list**: Read the file contents directly
2. **Recent changes**: Use `git diff --staged` or `git diff HEAD~N` to capture what changed
3. **Full module**: Collect all files under a directory

Confirm with the user: "I'll send the following to Codex for review: `<file list or diff summary>`. Proceed?"

### Step 1: Spawn a Subagent to Run Codex Review

**CRITICAL: Each review round MUST run inside a subagent** using the Agent tool. This keeps the main conversation context clean and prevents long codex outputs from polluting the primary thread.

Spawn a `general-purpose` subagent with a prompt like:

```
You are running a Codex code review round. Your job:

1. Call codex via Bash with the review prompt below.
2. Capture the raw Codex response.
3. Return a concise summary containing:
   - The verdict (APPROVED or NEEDS_REVISION)
   - Each finding: ID, severity, category, file, line range, description, and suggestion
   - Any errors encountered

Do NOT evaluate or apply the findings — just report them back.
```

The subagent invokes codex with a prompt that asks it to:

1. Check for bugs, logic errors, and incorrect behavior
2. Identify security vulnerabilities (injection, auth bypass, data exposure, etc.)
3. Flag performance issues and resource leaks
4. Assess error handling and edge case coverage
5. Review code style, naming, and readability
6. Check for missing or incorrect type annotations
7. Verify tests adequately cover the new code (if tests are in scope)
8. Return a structured verdict: `APPROVED` or `NEEDS_REVISION` with numbered findings

```bash
cat <<PROMPT | codex exec --full-auto -
You are a senior code reviewer. Review the following code and provide structured feedback.

For each issue found, output in this exact format:
  FINDING-<N>: <severity: CRITICAL|MAJOR|MINOR>
  CATEGORY: <bug|security|performance|error-handling|style|testing|logic>
  FILE: <file path>
  LINES: <start-end or single line number, if applicable>
  <description of the issue>
  SUGGESTION: <concrete fix — include corrected code snippet when possible>

At the end, output exactly one of:
  VERDICT: APPROVED — this code is ready for merge
  VERDICT: NEEDS_REVISION — the issues above must be addressed

Prioritize findings by impact:
- CRITICAL: Will cause incorrect behavior, data loss, or security vulnerabilities in production
- MAJOR: Significant bugs, missing error handling for likely scenarios, or performance problems
- MINOR: Style issues, naming improvements, minor simplifications

Here is the code to review:
$(cat <file1> <file2> ...)

$(git diff <base>..HEAD 2>/dev/null && echo "=== END DIFF ===" || true)
PROMPT
```

For large codebases, prefer sending the diff plus only the full text of changed files, rather than the entire repository.

### Step 2: Process Subagent Results

When the subagent returns, extract the structured findings from its response. Each finding has:

- **ID**: `FINDING-1`, `FINDING-2`, etc.
- **Severity**: `CRITICAL`, `MAJOR`, or `MINOR`
- **Category**: `bug`, `security`, `performance`, `error-handling`, `style`, `testing`, `logic`
- **File**: Which file the issue is in
- **Lines**: Where in the file (if identified)
- **Description**: What the issue is
- **Suggestion**: How to fix it, ideally with a code snippet

Also check the **verdict**: `APPROVED` or `NEEDS_REVISION`.

If the verdict is `APPROVED`, skip to Step 5 (wrap-up).

### Step 3: Evaluate Each Finding

For each finding, Claude Code (in the main conversation) makes an independent judgment:

#### 3a. AGREE — The finding is valid

Apply the fix to the code. Log the change:

```markdown
## Round <N> — Finding <ID>: ACCEPTED

- **File**: <file path>
- **Issue**: <description>
- **Action**: <what was changed in the code>
```

#### 3b. DISAGREE — The finding seems incorrect or inappropriate

Do NOT silently ignore it. Escalate to the user with full context:

```markdown
## Disagreement on Finding <ID> (<severity>)

**Codex says**: <description>
**Codex suggests**: <suggestion>
**File**: <file path>, lines <range>

**My assessment**: <why I think this is wrong, with reasoning>

**Options**:

1. Accept Codex's suggestion anyway — I'll modify the code
2. Reject and keep current code — I'll note the rejection in the review log
3. Modify differently — Tell me what you'd prefer
```

Wait for user input before proceeding. Record the decision **with reasoning** in the review log:

```markdown
## Round <N> — Finding <ID>: REJECTED

- **File**: <file path>
- **Codex issue**: <description>
- **Codex suggestion**: <suggestion>
- **Rejection reason**: <why the suggestion was not adopted — from CC assessment and/or user input>
```

#### 3c. PARTIALLY AGREE — Valid concern but different fix preferred

Explain to the user what you'd change differently, and ask for confirmation:

```markdown
## Partial Agreement on Finding <ID>

**Codex says**: <description>
**Codex suggests**: <suggestion>
**My proposed alternative**: <different fix with reasoning>

Accept my alternative, or use Codex's original suggestion?
```

Record the decision **with reasoning** in the review log:

```markdown
## Round <N> — Finding <ID>: PARTIALLY ACCEPTED

- **File**: <file path>
- **Codex issue**: <description>
- **Codex suggestion**: <suggestion>
- **Alternative applied**: <what was actually changed and why it differs from Codex's suggestion>
```

### Step 4: Resubmit for Next Round (Cross-Model Discussion)

**CRITICAL**: The resubmission must carry full decision context so Codex can understand _why_ certain suggestions were rejected or modified. This enables a genuine cross-model discussion rather than a one-sided review loop.

After all findings are processed and the code is updated:

1. Increment the round counter
2. Check if round > 10 (max rounds). If so, go to Step 5 with a timeout notice
3. Save a snapshot of the diff after revision: `git diff > <workspace>/review-rounds/round-<N>/diff-after-revision.patch`
4. Append the current round's decisions to `<workspace>/review-log.md` (this is the prior context for the next round)
5. **Spawn a new subagent** (repeat from Step 1) with the updated round number and `--prior-context` pointing to the review log

The review log passed as `--prior-context` allows Codex to see the full decision history. The subagent's resubmission prompt to Codex will include:

```
This is round <N> of code review. The prior context below contains the full decision log from
previous rounds, including which findings were ACCEPTED, REJECTED (with reasons), or
PARTIALLY ACCEPTED (with alternative fixes and rationale).

When you encounter a previously rejected or modified suggestion:
- If the rejection reason is valid, do NOT re-raise the same issue.
- If you believe the rejection reason is flawed or the alternative fix is insufficient,
  you MAY re-raise with a COUNTERARGUMENT that specifically addresses the stated reason.
  Use this format:
    FINDING-<N>: <CRITICAL|MAJOR|MINOR> [RE-RAISED]
    CATEGORY: <bug|security|performance|error-handling|style|testing|logic>
    FILE: <file path>
    Previously raised in Round <M> as FINDING-<K>, rejected because: <stated reason>
    COUNTERARGUMENT: <why the rejection reason is insufficient or the alternative is flawed>
    SUGGESTION: <revised suggestion that addresses the concerns>

Focus on:
- Whether previously accepted fixes actually resolve the original issues (check for regressions)
- Any NEW issues introduced by the revisions
- Genuine disagreements where the rejection rationale may be incorrect

===== PRIOR REVIEW DECISIONS =====
<content of review-log.md>
===== END PRIOR DECISIONS =====

Please review the UPDATED code below.
If all concerns are adequately addressed and no new critical issues exist, respond with VERDICT: APPROVED.
```

### Step 5: Wrap Up

When the loop ends (either `APPROVED` or max rounds reached), produce a summary:

```markdown
# Code Review Summary

- **Scope**: <file list or diff description>
- **Rounds**: <N> of 10
- **Final Verdict**: <APPROVED | MAX_ROUNDS_REACHED>

## Review History

### Round 1

- Finding 1 (CRITICAL, bug, `src/auth.py:42-58`): <desc> → ACCEPTED, code modified
- Finding 2 (MAJOR, security, `src/api.py:101`): <desc> → REJECTED by user (reason: ...)
- Finding 3 (MINOR, style, `src/utils.py:15`): <desc> → ACCEPTED

### Round 2

- Finding 1 (MINOR, testing, `tests/test_auth.py`): <desc> → ACCEPTED
- VERDICT: APPROVED

## Statistics

- Total findings: <count>
- Accepted: <count>
- Rejected: <count>
- User-escalated: <count>

## By Category

- Bugs: <count>
- Security: <count>
- Performance: <count>
- Error handling: <count>
- Style: <count>
- Testing: <count>
- Logic: <count>
```

Save this summary to `<workspace>/review-summary.md`.

If max rounds reached without approval, tell the user clearly:

```
⚠️ Codex did not approve the code after 10 rounds.
Remaining concerns: <list>
You may want to review these manually or address them before merging.
```

## Review Log Format

Maintain a running log at `<workspace>/review-log.md` across all rounds:

```markdown
# Review Log: <scope description>

Started: <timestamp>

## Round 1 — <timestamp>

### Codex Verdict: NEEDS_REVISION

| Finding | Severity | Category | File | CC Decision | User Override | Action |
| ------- | -------- | -------- | ---- | ----------- | ------------- | ------ |
| F-1     | CRITICAL | bug      | src/auth.py:42 | AGREE | — | Fixed null check |
| F-2     | MAJOR    | security | src/api.py:101 | DISAGREE | REJECT | Kept original |

### Code changes applied:

<brief description of modifications made>

## Round 2 — <timestamp>

...
```

## Edge Cases

### Codex returns unparseable output

If the Codex response doesn't follow the expected format:

1. Save the raw response for the user to review
2. Attempt best-effort extraction of any identifiable concerns
3. Ask the user: "Codex returned unstructured feedback. Want me to interpret it as best I can, or retry the round?"

### Codex CLI errors or timeouts

```bash
# Retry once with a simpler prompt if codex fails
if [ $? -ne 0 ]; then
    echo "Codex CLI failed. Retrying with simplified prompt..."
    # retry logic
fi
```

If Codex fails twice, report to the user and offer to skip this round or abort.

### Very large diffs (>5000 lines changed)

For large changesets, split the review by file or module and review each chunk separately, then do a final holistic pass focusing on cross-cutting concerns (API consistency, shared state, integration issues). Warn the user that large diffs may produce lower-quality reviews due to context limits.

### Code has no tests

If the reviewed code lacks test coverage, Codex should flag this. Claude Code should assess whether tests are expected for the change scope and, if so, offer to write them before resubmission.

### All findings in a round are rejected

If CC disagrees with every finding and the user confirms rejection of all, still resubmit. Include the rejection context so Codex can reassess. If the same findings keep recurring across rounds, flag this pattern to the user — it likely indicates a genuine disagreement between models that needs human judgment.

### Finding involves refactoring outside the review scope

If Codex suggests changes to files not in the original review scope, flag this to the user: "Codex is suggesting changes to `<file>` which is outside the current review scope. Want me to include it?" Do not modify code outside scope without explicit approval.

## Configuration

The skill uses these defaults, overridable by the user:

| Parameter           | Default                    | Description                                         |
| ------------------- | -------------------------- | --------------------------------------------------- |
| `max-rounds`        | 10                         | Maximum review-revision cycles                      |
| `severity-filter`   | all                        | Review all severities, or only CRITICAL+MAJOR       |
| `auto-accept-minor` | false                      | Auto-apply MINOR findings without user confirmation |
| `workspace`         | `./codex-review-workspace` | Directory for review artifacts                      |
| `include-tests`     | true                       | Whether to include test files in the review scope   |
| `diff-only`         | false                      | Send only the diff rather than full file contents   |

## Safety Principles

1. **Never blindly accept Codex feedback** — CC independently evaluates every finding
2. **Human-in-the-loop for disagreements** — When CC and Codex disagree, the user decides
3. **Full audit trail** — Every decision, accepted or rejected, is logged with reasoning
4. **Bounded loops** — Hard cap at 10 rounds prevents infinite back-and-forth
5. **Transparency** — User sees exactly what Codex said, what CC thinks, and what changed
6. **Scope discipline** — Do not modify code outside the agreed review scope without user approval
7. **No silent rewrites** — Every code change is logged with the finding that motivated it
