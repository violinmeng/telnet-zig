# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Zig telnet client (`telnet-zig`). Single-service project — no databases, Docker, or external dependencies beyond the Zig compiler. See `README.md` for usage.

### Zig version

This project requires **Zig 0.14.0**. The Zig compiler is installed at `~/zig/zig-linux-x86_64-0.14.0/zig` and added to `PATH` via `~/.bashrc`. Verify with `zig version`.

### Common commands

| Task | Command |
|------|---------|
| Build | `zig build` |
| Test | `zig build test` |
| Lint/Format check | `zig fmt --check .` |
| Auto-format | `zig fmt .` |
| Run (with args) | `zig build run -- telnet://host:port` |
| Run built binary | `./zig-out/bin/telnet-zig host:port` |
| Clean | `rm -rf zig-cache zig-out .zig-cache` |

The `justfile` provides shortcuts (`just build`, `just run`, `just fmt`, `just nasa`, `just clean`) but `just` is optional.

### Gotchas

- The Zig package manager automatically fetches the `zig-clap` dependency on first build. No separate install step is needed.
- The telnet client is interactive (reads stdin). When testing the connection programmatically, use `timeout` to avoid hanging: `timeout 15 ./zig-out/bin/telnet-zig horizons.jpl.nasa.gov:6775`. An `EndOfStream` error is expected when the remote server closes the connection or the timeout fires.
- Build artifacts go to `zig-out/` and cache to `.zig-cache/`. Both are gitignored.
