#!/usr/bin/env bash
# =============================================================================
# install.sh — Install skills into Claude Code
# =============================================================================
#
# MODES
# -----
#
#   --global  (default)
#       Wires the skills repo into Claude Code's *global* memory so it is
#       available in every project / session on this machine:
#
#         1. Appends an @-import of this repo's CLAUDE.md to ~/.claude/CLAUDE.md
#            so Claude always loads the skills navigation map.
#         2. Materialises each skill wrapper from skills/ into
#            ~/.claude/skills/ (substituting the real repo path for the
#            ${CLAUDE_PLUGIN_ROOT} placeholder) so slash commands like /euler and
#            /slurm are available everywhere.
#
#   --project <PROJECT_DIR>
#       Wires the skills repo into a single project's CLAUDE.md only.
#       Useful when the skills repo is a git submodule inside a project.
#
#         1. Appends an @-import of this repo's CLAUDE.md to
#            <PROJECT_DIR>/CLAUDE.md (creating the file if it does not exist).
#         2. Does NOT touch ~/.claude/ — skills are scoped to that project only.
#
# USAGE
# -----
#   chmod +x install.sh
#
#   # Global install (default)
#   ./install.sh
#   ./install.sh --global
#
#   # Per-project install (skills repo is a submodule at .skills/)
#   ./install.sh --project /path/to/my-project
#
#   # One-liner after cloning (global)
#   git clone https://github.com/<YOU>/skills.git ~/skills && ~/skills/install.sh
#
#   # One-liner as a submodule
#   cd my-project
#   git submodule add https://github.com/<YOU>/skills.git .skills
#   .skills/install.sh --project .
#
# Re-running is safe — the script is idempotent in both modes.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

step() { echo; blue "▶ $*"; }
ok()   { green "  ✓ $*"; }
skip() { yellow "  ↩ $*"; }
warn() { red    "  ✗ $*"; }

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [--global]
  $(basename "$0") --project <PROJECT_DIR>
  $(basename "$0") --help

Options:
  --global              Install into ~/.claude/ (default, available in all sessions)
  --project <dir>       Install into <dir>/CLAUDE.md only (per-project / submodule mode)
  -h, --help            Show this help message

Examples:
  # Global install
  ./install.sh

  # Per-project (when this repo is a submodule at .skills/)
  ./install.sh --project /path/to/my-project
EOF
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

MODE="global"
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)
            MODE="global"
            shift
            ;;
        --project)
            if [[ -z "${2:-}" ]]; then
                warn "--project requires a directory argument"
                echo
                usage
                exit 1
            fi
            MODE="project"
            PROJECT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            warn "Unknown argument: $1"
            echo
            usage
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

# Absolute path to this skills repo, regardless of where the script is called from.
SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMPORT_LINE="@${SKILLS_ROOT}/CLAUDE.md"
IMPORT_MARKER="# === Infrastructure Skills Repository ==="

# ---------------------------------------------------------------------------
# MODE: global
# ---------------------------------------------------------------------------

install_global() {
    CLAUDE_DIR="$HOME/.claude"
    CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
    SKILLS_DIR="$CLAUDE_DIR/skills"
    WRAPPERS_DIR="$SKILLS_ROOT/skills"

    # ── Step 1: Ensure ~/.claude/ exists ──────────────────────────────────

    step "Ensuring $CLAUDE_DIR exists"
    mkdir -p "$CLAUDE_DIR"
    ok "Directory ready: $CLAUDE_DIR"

    # ── Step 2: Add @-import to ~/.claude/CLAUDE.md ───────────────────────

    step "Configuring global memory: $CLAUDE_MD"

    if [[ -f "$CLAUDE_MD" ]] && grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
        skip "Import already present in $CLAUDE_MD"
    else
        {
            echo ""
            echo "$IMPORT_MARKER"
            echo "# Skills for accessing infrastructure (clusters, storage, services)."
            echo "# Source: $SKILLS_ROOT"
            echo "$IMPORT_LINE"
        } >> "$CLAUDE_MD"
        ok "Import added to $CLAUDE_MD"
    fi

    # ── Step 3: Materialise skill wrappers into ~/.claude/skills/ ─────────

    step "Installing skill wrappers into $SKILLS_DIR"
    mkdir -p "$SKILLS_DIR"

    if [[ ! -d "$WRAPPERS_DIR" ]]; then
        warn "skills/ not found at $WRAPPERS_DIR — skipping"
    else
        for wrapper_dir in "$WRAPPERS_DIR"/*/; do
            skill_name="$(basename "$wrapper_dir")"
            src_skill_md="$wrapper_dir/SKILL.md"

            if [[ ! -f "$src_skill_md" ]]; then
                skip "No SKILL.md in $wrapper_dir — skipping"
                continue
            fi

            dest_dir="$SKILLS_DIR/$skill_name"
            dest_skill_md="$dest_dir/SKILL.md"
            mkdir -p "$dest_dir"

            # Substitute ${CLAUDE_PLUGIN_ROOT} with the real absolute path.
            # (In the native plugin system this variable is resolved automatically;
            #  here we bake it in at install time so the fallback method works too.)
            sed "s|\${CLAUDE_PLUGIN_ROOT}|${SKILLS_ROOT}|g" "$src_skill_md" > "$dest_skill_md"
            ok "Installed skill: $skill_name → $dest_skill_md"
        done
    fi

    # ── Step 4: Verify ────────────────────────────────────────────────────

    step "Verification"

    echo
    echo "  $CLAUDE_MD:"
    if grep -qF "$IMPORT_LINE" "$CLAUDE_MD" 2>/dev/null; then
        ok "Import line present"
        grep -n "$IMPORT_LINE\|$IMPORT_MARKER" "$CLAUDE_MD" | sed 's/^/     /'
    else
        warn "Import line NOT found — something went wrong"
    fi

    echo
    echo "  $SKILLS_DIR/:"
    if [[ -d "$SKILLS_DIR" ]]; then
        found_any=false
        for d in "$SKILLS_DIR"/*/; do
            [[ -d "$d" ]] || continue
            skill="$(basename "$d")"
            if [[ -f "$d/SKILL.md" ]]; then
                ok "/$skill  →  $d/SKILL.md"
                found_any=true
            fi
        done
        [[ "$found_any" == true ]] || skip "No skill wrappers installed"
    else
        warn "$SKILLS_DIR does not exist"
    fi

    # ── Done ──────────────────────────────────────────────────────────────

    echo
    green "================================================================"
    green " Global installation complete."
    green "================================================================"
    echo
    echo "  Skills root   : $SKILLS_ROOT"
    echo "  Global memory : $CLAUDE_MD"
    echo "  Skills dir    : $SKILLS_DIR"
    echo
    echo "  What happens next:"
    echo "   • Every Claude Code session will load the skills navigation map"
    echo "     from this repo's CLAUDE.md automatically."
    echo "   • Slash commands like /euler and /slurm are available in all"
    echo "     Claude Code sessions on this machine."
    echo
    echo "  To update after editing skill docs:"
    echo "   • No action needed — skill files are read from $SKILLS_ROOT"
    echo "     at runtime, so edits take effect immediately."
    echo "   • Re-run ./install.sh only if you add new skills/."
    echo
    echo "  To uninstall:"
    echo "   • Remove the block between the === markers in $CLAUDE_MD"
    echo "   • Delete $SKILLS_DIR"
    echo
}

# ---------------------------------------------------------------------------
# MODE: project
# ---------------------------------------------------------------------------

install_project() {
    # Resolve PROJECT_DIR to an absolute path
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    PROJECT_CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

    step "Installing into project: $PROJECT_DIR"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        warn "Project directory does not exist: $PROJECT_DIR"
        exit 1
    fi

    step "Configuring $PROJECT_CLAUDE_MD"

    if [[ -f "$PROJECT_CLAUDE_MD" ]] && grep -qF "$IMPORT_LINE" "$PROJECT_CLAUDE_MD"; then
        skip "Import already present in $PROJECT_CLAUDE_MD"
    else
        {
            echo ""
            echo "$IMPORT_MARKER"
            echo "# Skills for accessing infrastructure (clusters, storage, services)."
            echo "# Source: $SKILLS_ROOT"
            echo "$IMPORT_LINE"
        } >> "$PROJECT_CLAUDE_MD"
        ok "Import added to $PROJECT_CLAUDE_MD"
    fi

    # ── Verify ────────────────────────────────────────────────────────────

    step "Verification"

    echo
    echo "  $PROJECT_CLAUDE_MD:"
    if grep -qF "$IMPORT_LINE" "$PROJECT_CLAUDE_MD" 2>/dev/null; then
        ok "Import line present"
        grep -n "$IMPORT_LINE\|$IMPORT_MARKER" "$PROJECT_CLAUDE_MD" | sed 's/^/     /'
    else
        warn "Import line NOT found — something went wrong"
    fi

    # ── Done ──────────────────────────────────────────────────────────────

    echo
    green "================================================================"
    green " Per-project installation complete."
    green "================================================================"
    echo
    echo "  Skills root    : $SKILLS_ROOT"
    echo "  Project CLAUDE : $PROJECT_CLAUDE_MD"
    echo
    echo "  What happens next:"
    echo "   • Claude Code sessions opened inside $PROJECT_DIR will"
    echo "     automatically load the skills navigation map."
    echo "   • Skills are scoped to this project only — ~/.claude/ is"
    echo "     not modified."
    echo
    echo "  If the skills repo is a git submodule, keep it up to date with:"
    echo "   git submodule update --remote .skills"
    echo
    echo "  To uninstall:"
    echo "   • Remove the block between the === markers in $PROJECT_CLAUDE_MD"
    echo
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$MODE" in
    global)  install_global  ;;
    project) install_project ;;
esac
