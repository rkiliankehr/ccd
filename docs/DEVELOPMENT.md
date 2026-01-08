# CCD Development Journey

This document captures the evolution of the `ccd` (Custom Change Directory) script, including design decisions, performance optimizations, and lessons learned.

## Overview

`ccd` is a shell utility for quickly navigating to directories by typing partial names instead of full paths. It maintains a cached index of directories and supports fuzzy matching with `fzf`.

## Initial State

The original script had a simple approach:

1. Run `find $HOME -type d` to get ALL directories
2. Filter with multiple `grep -v` pipes to exclude unwanted paths
3. Store in `~/.ccd` cache file
4. Search cache with `grep` and `cd` to first match

**Problems:**
- Cache contained 42,000+ directories
- Cache rebuild took infinite time (never completed)
- Entered every directory including `node_modules`, `venv`, `.git/objects`, etc.
- No interactive selection when multiple matches

## Improvement 1: fzf Integration

**Commit:** `db60b93`

**Change:** When multiple directories match, open `fzf` for interactive selection instead of blindly picking the first match.

```zsh
if [ "$match_count" -eq 1 ]; then
    hit="$matches"
elif command -v fzf >/dev/null 2>&1; then
    hit=$(echo "$matches" | fzf --height=40% --reverse --prompt="ccd> ")
else
    hit=$(echo "$matches" | head -1)
fi
```

**Rationale:** Users often have similarly-named directories (e.g., `project-v1`, `project-v2`). Interactive selection is faster than typing more characters to disambiguate.

## Improvement 2: Configurable Ignore Patterns

**Commit:** `db60b93`

**Change:** Replaced hardcoded `grep -v` chain with external config file `~/.ccd.ignore`.

**Before:**
```bash
find ... | grep -v node_modules | grep -v __pycache__ | grep -v .git ...
```

**After:**
```bash
find ... | grep -Evf "$CCD_IGNORE"
```

**Rationale:**
- Users can customize exclusions without editing the script
- Single `grep -Evf` is cleaner than pipe chain
- Patterns use regex for flexibility

**Default patterns include:**
- Hidden directories (`/\.`)
- Package managers (`node_modules`, `site-packages`, `.cargo`, `.npm`)
- Build outputs (`target`, `build`, `dist`, `out`)
- IDE configs (`.vscode`, `.idea`)
- OS-specific (`Library`, `DerivedData`)

## Improvement 3: Workspace Pruning

**Commit:** `db60b93`

**Problem:** Even with ignore patterns, we were indexing deep into project subdirectories. If I have `/home/user/projects/myproject/src/components/Button/`, I really just want `/home/user/projects/myproject/` — I can navigate within the project using normal `cd`.

**Solution:** Introduce "workspace markers" — files/directories whose presence indicates a project root:

- `.git` — version control
- `package.json` — Node.js
- `Cargo.toml` — Rust
- `go.mod` — Go
- `pyproject.toml` — Python
- etc.

**Logic:**
1. Find all directories containing workspace markers → "workspace roots"
2. Include workspace roots in cache
3. Exclude all descendants of workspace roots

**Config file:** `~/.ccd.prune` (exact names, not regex)

**Result:** Cache reduced from 42,000 to ~3,600 directories.

## Improvement 4: find Pruning

**Commit:** `acbbaaa`

**Problem:** The naive approach:
```bash
find $HOME -type d | grep -Evf ~/.ccd.ignore
```

This traverses EVERY directory (including millions inside `node_modules`) and filters afterward. The damage is done — we already wasted time traversing.

**Solution:** Use `find`'s `-prune` to never enter excluded directories:

```bash
find $HOME \( -name "node_modules" -o -name ".venv" ... \) -prune -o -type d -print
```

**Key insight:** `-prune` tells `find` "don't descend into this directory." Combined with no `-print` for pruned items, we skip them entirely.

**Performance:** Cache rebuild went from "infinite" to ~56 seconds.

## Improvement 5: Single-Pass Processing

**Commit:** `acbbaaa`

**Problem:** We were running `find` twice:
1. Once to get all directories
2. Once to find workspace markers

**Solution:** Single `find` that outputs both directories and marker files, then `awk` processes them in one pass:

```bash
find ... -o \( -type d -o \( $marker_expr \) \) -print | awk '
{
    # If filename matches a marker, record parent as workspace root
    # Otherwise, store as directory
    # In END block, filter out descendants of workspace roots
}
'
```

**Performance:** 56s → 31s (45% faster)

## Improvement 6: fd Integration

**Commit:** `d99eed0`

**Problem:** Profiling revealed `find` took 77% of execution time (24.6s), `awk` only 23% (7.5s). The bottleneck was filesystem traversal.

**Solution:** Use `fd` (Rust-based find alternative) which is ~21x faster:

```bash
fd --type d --hidden --no-ignore --exclude node_modules ...
```

**Key differences:**
- `fd` uses parallel traversal
- Written in Rust, optimized for speed
- Simpler exclude syntax (`--exclude` vs complex `-prune` expressions)

**Challenges encountered:**

1. **Trailing slashes:** `fd` outputs `/path/to/dir/`, `find` outputs `/path/to/dir`. Had to strip trailing slashes for consistent path matching.

2. **Marker detection:** `.git` is a directory, not a file. Initial `fd --type f` missed it. Fixed by removing type restriction for marker search.

3. **Exclude conflicts:** We excluded `.git` from directory listing (don't want `.git/objects` contents) but needed to find `.git` as a workspace marker. Solution: separate exclude lists for directory traversal vs marker search.

**Performance:** 31s → 12s (2.6x faster)

## Improvement 7: Cron Support

**Commit:** `0c3824e`

**Problem:** Script uses `return` statements which only work when sourced. For cron execution, need `exit`.

**Solution:** Detect execution context:

```zsh
if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file ]]; then
    _CCD_SOURCED=1
else
    _CCD_SOURCED=0
fi

# Then at exit points:
[[ $_CCD_SOURCED -eq 1 ]] && return 0 || exit 0
```

**Cron entry:** `*/15 * * * * $HOME/bin/ccd -n >/dev/null 2>&1`

## Performance Summary

| Version | Cache Size | Rebuild Time | Notes |
|---------|------------|--------------|-------|
| Original | 42,403 | ∞ (never finished) | No pruning |
| + find pruning | 3,663 | 56s | Skip heavy dirs |
| + single-pass | 3,663 | 31s | One find, awk processing |
| + fd | 3,437 | 12s | Parallel Rust-based traversal |

**Total improvement:** From infinite/42k to 12s/3.4k

## Architecture

```
~/.ccd           # Directory cache (path + keywords, sorted by depth)
~/.ccd.ignore    # Exclusion patterns (regex)
~/.ccd.prune     # Workspace markers (exact names)
~/bin/ccd        # The script

.ccd.keywords    # Per-directory keyword file (optional)

Execution modes:
1. Sourced via shell function (for cd to work)
2. Direct execution (for cron)
```

## Key Design Decisions

### Why source instead of execute?

The script needs to change the shell's working directory. A subprocess cannot change the parent's directory. Solution: source the script so it runs in the current shell context.

```zsh
# In .zshrc
function ccd() {
    source $HOME/bin/ccd "$@"
}
```

### Why two config files (ignore vs prune)?

Different purposes, different formats:

- **ignore:** Directories to completely exclude (never index). Uses regex for flexibility. Example: `node_modules` anywhere, `\.git/objects`.

- **prune:** Workspace markers that indicate "stop descending." Uses exact names because we're matching specific files. Example: `package.json`, `Cargo.toml`.

### Why sort by path length?

```bash
awk '{ printf "%4d:%s\n", length($0), $0 }' | sort -n | cut -d':' -f2
```

Shorter paths appear first. When searching for "project", `/home/user/project` ranks above `/home/user/old/backup/project`. Users typically want the shortest match.

### Why fd over find?

- **Speed:** 21x faster in our tests (1s vs 22s for same traversal)
- **Simplicity:** `--exclude` is more intuitive than `-prune` expressions
- **Safety:** fd respects `.gitignore` by default (we disable with `--no-ignore`)

We keep `find` as fallback for systems without `fd`.

## Lessons Learned

1. **Profile before optimizing.** We assumed `awk` was slow; profiling revealed `find` was the bottleneck (77% of time).

2. **Prune early.** Filtering after traversal wastes time. Use `find -prune` or `fd --exclude` to never enter heavy directories.

3. **Question the requirements.** We didn't need every directory — just workspace roots. Reframing the problem led to 10x cache reduction.

4. **Tools matter.** Switching from `find` to `fd` gave 2.6x speedup with minimal code changes.

5. **Test both execution contexts.** Scripts that are both sourced and executed need careful handling of `return` vs `exit`.

6. **Hidden directories need care.** `.git` is both:
   - Something to exclude (`.git/objects` is huge)
   - A workspace marker (presence indicates project root)

   Solution: exclude `.git/objects` or use separate rules for different purposes.

## Improvement 8: Keyword-Based Search

**Problem:** Sometimes you can't remember the exact directory name, but you know what the project is about — "that API project" or "the certificate thing."

**Solution:** Add keyword tagging via `.ccd.keywords` files.

**Implementation:**

1. **Keyword file format:** Place `.ccd.keywords` in any directory with one keyword per line. Lines starting with `#` are comments.

```
# Keywords for this project
api
backend
authentication
```

2. **Cache format extended:** Keywords appended to path, prefixed with `#`:

```
/home/user/projects/myproject #api #backend #authentication
```

3. **Unified search:** `ccd api` matches both directory names AND keywords. No need to remember which is which.

4. **Multi-term OR search:** `ccd api server` finds directories matching "api" OR "server".

5. **Keyword-only search:** `ccd #backend` searches only keywords, not directory names.

6. **Visual distinction:** Keywords displayed in cyan in fzf for easy scanning.

**New commands:**

- `ccd -k` — Edit `.ccd.keywords` for current directory (creates template if missing)

**Key design decisions:**

- **Plain words in file, `#` prefix in display:** File uses plain words (easier to edit), cache/display uses `#` prefix (visual distinction).
- **Case-insensitive:** Keywords normalized to lowercase during indexing.
- **Validation warnings:** Special characters in keywords trigger warnings during rebuild.
- **Backward compatible:** Directories without keywords work exactly as before.

## Future Improvements

Potential enhancements if needed:

1. **Frecency scoring** — Prioritize recently/frequently used directories
2. **Incremental updates** — Only rescan changed directories
3. **Tab completion** — Shell completion for patterns

## Files

```
ccd-ng/
├── ccd                 # Main script
├── .ccd.keywords       # Example keywords for this project
└── docs/
    └── DEVELOPMENT.md  # This file

~/.ccd                  # Directory cache (with keywords)
~/.ccd.ignore           # Exclusion patterns (regex)
~/.ccd.prune            # Workspace markers (exact names)
```

## Commands Reference

```bash
ccd -n            # Rebuild cache (indexes .ccd.keywords files)
ccd -k            # Edit keywords for current directory
ccd -f TERM       # Find matching directories (list only)
ccd -h            # Show help
ccd TERM          # cd to match (fzf if multiple)
ccd TERM1 TERM2   # OR search: matches TERM1 or TERM2
ccd #keyword      # Search keywords only (not directory names)
```
