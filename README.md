# ccd — Quick Directory Navigation

Jump to any directory by typing a few characters. No more `cd ../../../somewhere/deep/in/your/filesystem`.

```
$ ccd myproject
/Users/you/work/clients/acme/myproject
```

## The Problem

You have hundreds of project directories scattered across your filesystem. You know the name — or at least part of it — but not the full path. Traditional `cd` requires the exact path. `autojump` and `z` require you to have visited the directory before.

## The Solution

`ccd` maintains a searchable index of your directories. Type any part of the name, and you're there. Multiple matches? Pick with fuzzy finder.

**Key features:**

- **Instant jumps** — Type `ccd api` to jump to your API project
- **Fuzzy matching** — Multiple matches open in `fzf` for selection
- **Keyword tags** — Tag directories with searchable keywords you'll remember
- **Smart indexing** — Only indexes project roots, not every nested folder
- **Fast** — Blazing fast cache rebuilds using `fd` under the hood

## Demo

```
$ ccd api
ccd>
  2/2
  /home/user/work/api-gateway
> /home/user/projects/payment-service #api #backend #payments
```

Keywords (shown in cyan) help you find directories by concept, not just name.

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/rkiliankehr/ccd/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/rkiliankehr/ccd.git
cd ccd
./install.sh
```

### Manual Install

1. Copy the script to your path:

```bash
cp ccd ~/bin/ccd
chmod +x ~/bin/ccd
```

2. Add the shell function to your `~/.zshrc` or `~/.bashrc`:

```bash
# ccd - quick directory navigation
function ccd() {
    source ~/bin/ccd "$@"
}
```

3. Reload your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

4. Build the initial cache:

```bash
ccd -n
```

## Requirements

- **zsh** or **bash**
- **fzf** — for interactive selection (highly recommended)
- **fd** — for fast indexing (optional, falls back to `find`)

Install on macOS:
```bash
brew install fzf fd
```

Install on Ubuntu/Debian:
```bash
sudo apt install fzf fd-find
```

## Usage

```bash
ccd project       # Jump to directory matching "project"
ccd api server    # Jump to directory matching "api" OR "server"
ccd #backend      # Search only keywords (not directory names)
ccd -n            # Rebuild the directory cache
ccd -k            # Edit keywords for current directory
ccd -f pattern    # Find matches without changing directory
```

## Keyword Tagging

Can't remember the directory name? Tag it with keywords you'll remember.

Create `.ccd.keywords` in any directory:

```
# Keywords for this project
api
backend
payments
```

Now `ccd payments` finds this directory even if "payments" isn't in the path.

Keywords appear in cyan in the fuzzy finder, so you can see what you've tagged.

## Configuration

`ccd` uses three config files in your home directory:

| File | Purpose |
|------|---------|
| `~/.ccd` | Directory cache (auto-generated) |
| `~/.ccd.ignore` | Patterns to exclude from indexing (regex) |
| `~/.ccd.prune` | Workspace markers that stop descent |

### Exclusion Patterns (~/.ccd.ignore)

Directories matching these patterns are never indexed:

```
node_modules
__pycache__
\.venv
target/debug
```

### Workspace Markers (~/.ccd.prune)

When `ccd` finds these files, it indexes that directory but doesn't descend further:

```
.git
package.json
Cargo.toml
go.mod
```

This keeps your cache lean — you get `/projects/myapp` but not `/projects/myapp/src/components/Button`.

## Automatic Cache Refresh

Add to your crontab for automatic updates:

```bash
crontab -e
```

```
*/15 * * * * ~/bin/ccd -n >/dev/null 2>&1
```

## How It Works

1. **Indexing:** Traverses your home directory using `fd` (or `find`), stopping at workspace roots
2. **Keyword collection:** Reads `.ccd.keywords` files and appends tags to cache entries
3. **Searching:** Grep-based matching against the cache, with `fzf` for disambiguation
4. **Navigation:** Selected path is passed to `cd` in your shell

The cache is a simple text file — one path per line, sorted by depth so shorter paths rank first.

### Performance

Originally developed on macOS, optimized for large home directories:

- Parallel traversal with `fd` for blazing fast indexing
- Smart pruning — never enters `node_modules`, `target`, etc.
- Workspace detection — indexes only project roots, not every nested folder
- Falls back to `find` if `fd` is not installed

## Shell Integration

The script must be **sourced** (not executed) to change your shell's directory. The install script sets this up automatically, but here's what it does:

**For zsh** (`~/.zshrc`):
```bash
function ccd() {
    source ~/bin/ccd "$@"
}
```

**For bash** (`~/.bashrc`):
```bash
function ccd() {
    source ~/bin/ccd "$@"
}
```

## Troubleshooting

**"No match found"**
- Run `ccd -n` to rebuild the cache
- Check `~/.ccd.ignore` isn't excluding your directory

**Cache is stale**
- Cache age warning appears after 5 days
- Run `ccd -n` or set up cron job

**fzf not working**
- Install fzf: `brew install fzf` or `apt install fzf`
- Without fzf, first match is used automatically

## License

MIT

## Contributing

Issues and pull requests welcome on GitHub.
