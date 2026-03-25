# Runtime leak on server removal

## Problem

`AgentRuntimeManager` caches `AgentRuntime` instances keyed by `serverId`.
When `ServerManager.removeServer()` is called, nothing evicts the cached
runtime. The orphaned `AgentRuntime` leaks:

- Active sessions and their signal state
- Spawn queue completers
- Root timeout timers
- A `StreamController` (`_sessionController`)
- Ephemeral threads that need server-side cleanup

The underlying `ServerConnection` is closed by `removeServer`, so the
runtime can't do useful work — but its resources aren't freed until app
close.

## Fix

1. Add `AgentRuntimeManager.evict(String serverId)` — disposes and removes
   the cached runtime.
2. Wire it into the server removal flow so `evict` is called whenever
   `removeServer` runs.

## Wiring challenge

`ServerManager` lives in the auth module; `AgentRuntimeManager` lives in
the room module. Options:

- **Callback**: `ServerManager` accepts an `onServerRemoved` callback, set
  by the flavor.
- **Caller-side**: The UI call sites that invoke `removeServer` also call
  `evict`. Requires threading `runtimeManager` to those widgets.

The callback approach keeps the coupling in the flavor where both objects
are already in scope.

## Scope

Separate effort after Slice C. Not blocking current functionality.

## Found during

Slice B code review, Chunk 2 (module wiring), 2026-03-25.
