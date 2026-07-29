# Pi OptMem extension

Persistent append-only memory for Pi, backed by [`optmem-js`](../../../../optmem-js).

## Behavior

- Initializes `~/.optmem/memory` on first use (or `$MEMORY_DIR`).
- Uses the structured `optmem-js` library API and its canonical action-result formatter directly—no subprocess, CLI arguments, stdout parsing, or duplicated result presentation.
- Instructs the primary agent to call `optmem` with action `wake` before any other tool in every session.
- Does not preload or inject wake results; startup follows the same explicit protocol as the CLI.
- Keeps only the newest context added explicitly with `/memory`.
- Registers the `optmem` tool for `wake`, `note`, `nap`, `recall`, `zoom`, and `forget`.
- Adds `/memory`, `/memory-note`, and `/memory-recall` commands.
- Uses `optmem-js`'s canonical action-tool guidance instead of duplicating its system prompt.
- Leaves compression to the primary agent; the extension never calls a model itself.
- Disables agent access for `--no-session` subprocesses (such as Pi subagents), or whenever `PI_OPTMEM_DISABLED=1`.

Run `./pi/setup` from the dotfiles repository to install the local `optmem-js` dependency and expose the extension through `~/.pi/agent/extensions`.
