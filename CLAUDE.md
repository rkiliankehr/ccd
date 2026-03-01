# ccd — Quick Directory Navigation

Single-file zsh script (`ccd`) that indexes directories under `$HOME` and lets you jump to any one by partial name or keyword tag.

## Project Structure

- `ccd` — Main script (~700 lines zsh). Must be **sourced** (not executed) for `cd` to affect the parent shell. Direct execution works for `ccd -n` (cache rebuild, e.g. via cron).
- `install.sh` — Installer: copies to `~/bin/ccd`, adds shell function to `.zshrc`/`.bashrc`
- `Makefile` — `make install` / `make uninstall`
- `docs/DEVELOPMENT.md` — Design decisions, performance history, architecture notes

## Runtime Files (on user's system)

- `~/.ccd` — Directory cache (one path per line, keywords appended as `#tag`)
- `~/.ccd.ignore` — Regex exclusion patterns
- `~/.ccd.prune` — Workspace marker names (exact match, stops descent)
- `.ccd.keywords` — Per-directory keyword file (one keyword per line)

## Key Commands

```bash
ccd <term>          # cd to matching directory (fzf if multiple)
ccd <a> <b>         # OR search: matches a OR b
ccd #keyword        # keyword-only search
ccd                 # browse all in fzf
ccd -n              # rebuild cache
ccd -k              # edit keywords for $PWD
ccd -f <term>       # find/show matches without cd
ccd -s <term>       # select dir, set $CDIR (no cd)
ccd -s              # browse all in fzf, set $CDIR
```

## Architecture Notes

- Script detects sourced vs direct execution via `ZSH_EVAL_CONTEXT` and uses `return` or `exit` accordingly.
- Cache rebuild uses `fd` (parallel Rust traversal) with `find` fallback.
- Workspace pruning: directories containing markers (`.git`, `package.json`, `Cargo.toml`, etc.) are indexed as roots; their descendants are excluded.
- Cache sorted by path length (shorter paths first).
- Keywords are case-insensitive, stored lowercase in cache.
- fzf display: paths in cyan, keywords in orange (`#tag`).

## Development Guidelines

- This is a **single-file shell script** — keep it that way. No compilation, no dependencies beyond zsh + coreutils.
- `fzf` and `fd` are optional (recommended) dependencies. Always provide fallbacks.
- Test both sourced and direct execution modes.
- No tests exist yet.
