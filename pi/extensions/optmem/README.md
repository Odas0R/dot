# Pi OptMem extension

Persistent append-only memory for Pi, backed by [`optmem-js`](../../../../optmem-js).

## Behavior

- Initializes `~/.optmem/memory` on first use (or `$MEMORY_DIR`).
- Uses the structured `optmem-js` library API and its canonical action-result formatter directly—no subprocess, CLI arguments, stdout parsing, or duplicated result presentation.
- Wakes memory when a Pi session starts and injects the result into model context.
- Keeps only the newest injected wake context when a session is resumed.
- Registers the `optmem` tool for `wake`, `note`, `nap`, `recall`, `zoom`, and `forget`.
- Adds `/memory`, `/memory-note`, and `/memory-recall` commands.
- Uses `optmem-js`'s canonical action-tool guidance instead of duplicating its system prompt.
- Leaves compression to the primary agent; the extension never calls a model itself.
- Skips automatic loading and agent access for `--no-session` subprocesses (such as Pi subagents), or whenever `PI_OPTMEM_DISABLED=1`.

Run `./pi/setup` from the dotfiles repository to install the local `optmem-js` dependency and expose the extension through `~/.pi/agent/extensions`.
