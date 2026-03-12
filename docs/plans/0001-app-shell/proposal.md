# Proposal: Soliplex Frontend Shell — Modular Architecture

**Status:** Proposed
**Date:** 2026-03-11
**Branch:** `feat/new_frontend`

## Context

The old `soliplex_frontend` is a white-label Flutter app configured via
branding, URLs, feature flags, and theme colors. Features are controlled by
flags rather than composed as independent units, and infrastructure (auth,
agent, routing) is not pluggable. This repo replaces it with a modular
architecture where features are composed by including/excluding module
functions. It serves as both a **runnable app** and an **importable library**.

## Proposed Design

### Module Composition

Each module is a plain Dart function that receives dependencies via
**constructor injection** and returns a `ModuleContribution` (routes +
Riverpod overrides). The compiler enforces dependency order — you can't call
a module function without providing its deps.

```dart
class ModuleContribution {
  final List<RouteBase> routes;    // unmodifiable
  final List<Override> overrides;  // unmodifiable

  ModuleContribution({
    List<RouteBase> routes = const [],
    List<Override> overrides = const [],
  })  : routes = List.unmodifiable(routes),
        overrides = List.unmodifiable(overrides);
}
```

```dart
ModuleContribution authModule({required AuthState auth}) => ModuleContribution(
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
  ],
  overrides: [
    authStateProvider.overrideWithValue(auth),
  ],
);
```

`ShellConfig` takes a list of modules and flattens them:

```dart
class ShellConfig {
  final String appName;
  final ThemeData theme;
  final String initialRoute;
  final List<ModuleContribution> modules;  // unmodifiable

  ShellConfig({
    required this.appName,
    required this.theme,
    this.initialRoute = '/',
    List<ModuleContribution> modules = const [],
  }) : modules = List.unmodifiable(modules);

  List<RouteBase> get routes => modules.expand((m) => m.routes).toList();
  List<Override> get overrides => modules.expand((m) => m.overrides).toList();
}
```

**Flavor functions** compose modules into a `ShellConfig`. Adding or removing
a module is one line:

```dart
ShellConfig standard() {
  final auth = UnauthenticatedState();
  return ShellConfig(
    appName: 'Soliplex',
    theme: ThemeData.light(),  // plain ThemeData; no custom palette wrapper yet
    modules: [
      authModule(auth: auth),
      lobbyModule(auth: auth),
      chatModule(auth: auth),
    ],
  );
}
```

For structural navigation (bottom nav, drawers), a navigation module accepts
child `ModuleContribution` objects (not just routes) so their overrides are
preserved. Feature modules stay ignorant of the navigation shell:

```dart
ShellConfig standardWithNav() {
  final auth = UnauthenticatedState();
  final lobby = lobbyModule(auth: auth);
  final chat = chatModule(auth: auth);
  return ShellConfig(
    appName: 'Soliplex',
    theme: ThemeData.light(),
    modules: [
      authModule(auth: auth),
      shellNavigationModule(children: [lobby, chat]),
    ],
  );
}
```

`runSoliplexShell(config)` validates routes (recursive tree walk: no duplicate
paths — parameterized segments normalized before comparison so `/:id` and
`/:name` at the same position are duplicates; initial route exists when routes
are non-empty; no path shadowing — a parameterized sibling route must not
appear before a literal sibling route), builds a GoRouter, collects all
overrides into a single root `ProviderScope`, and renders
`MaterialApp.router`. Syntax validation (leading slashes, empty paths) is left
to GoRouter itself.

To disable a module, remove its call. Runtime feature flags (A/B, remote
config) can be added to flavor functions later.

**Known limitations:**

- If two modules override the same Riverpod provider, the last one wins
  silently. Acceptable with few overrides; fix later with explicit provider
  registration in the flavor function if needed.

**Deliberate omissions:**

- **No module lifecycle hooks** — Riverpod providers handle disposal;
  initialization happens in flavor functions. An optional async callback
  can be added to `ModuleContribution` later if needed.
- **No error route** — GoRouter's `errorBuilder` can be added to
  `ShellConfig` when needed.
- **No scoped DI for logout** — on logout, recreate the entire app by
  re-running `runSoliplexShell` with fresh state from the flavor function.
  The root widget must use a unique key (e.g. `UniqueKey()`) on each boot
  so Flutter tears down the old `ProviderScope` instead of reconciling it.
  No nested `ProviderScope`s or manual reset methods needed.

### State & Reactivity

```text
soliplex_agent (signals_core)  →  Module functions (constructor injection)  →  Flutter UI (Riverpod DI + signals)
```

- Riverpod is **DI/service locator only** — no AsyncNotifier or FutureProvider chains
- `signals` package bridges signal reactivity to Flutter widget rebuilds
- Widgets use `ref.watch` to obtain service instances, then `signal.watch(context)` to observe reactive state within them. Side effects use Signal `effect()` or `SignalsMixin`, not `ref.listen`
- All wiring is explicit at the call site; missing deps are compile errors

### Network Observability (module-level, not shell)

The shell itself has no network layer. The agent module (future work) uses
`soliplex_agent`'s `HttpObserver` / `ObservableHttpClient` for observability.
All REST and SSE traffic flows through this stack with automatic auth-token
redaction. Observer callbacks: `onRequest`, `onResponse`, `onError`,
`onStreamStart`, `onStreamEnd`.

```text
DartHttpClient → ObservableHttpClient → AuthenticatedHttpClient → ...
                        │
                        ├── Inspector module (HttpObserver → UI panel)
                        └── Other HttpObservers (Sentry, logging, etc.)
```

Modules implement `HttpObserver` and register with the agent's HTTP stack
directly — no shell-level abstraction.

## Key Design Decisions

1. **Constructor injection** — explicit wiring, compile-time dependency checking
2. **Modules are cohesive units** — routes + overrides in one `ModuleContribution`; no base class, no registry
3. **Riverpod as widget-tree DI only** — overrides collected into single root `ProviderScope`
4. **Signals for reactivity** — `soliplex_agent` already uses them; UI bridges via `signals` package
5. **Interfaces, not implementations** — `AuthState` is abstract; flavors create concrete instances
6. **Composition over configuration** — modules included/excluded by presence in flavor functions
7. **Shell has no soliplex_agent dependency** — agent integration comes via a module
8. **All network activity observable** — via `soliplex_agent`'s `HttpObserver` infrastructure
9. **App + library in one repo** — unified `ai.soliplex.client` identifiers for seamless replacement

## Package Structure

```text
lib/
├── soliplex_frontend.dart              ← public barrel export
├── main.dart                           ← app entry point
├── src/
│   ├── core/
│   │   ├── shell.dart                  ← runSoliplexShell(), SoliplexShell widget
│   │   ├── shell_config.dart           ← ShellConfig, ModuleContribution
│   │   └── router.dart                 ← route validation, GoRouter assembly
│   │
│   ├── interfaces/
│   │   └── auth.dart                   ← AuthState abstract class
│   │
│   └── flavors/
│       └── standard.dart               ← standard flavor function
```

## Implementation Steps

### Step 1: Project Scaffold ✅

- [x] `pubspec.yaml` with dependencies
- [x] `lib/soliplex_frontend.dart` (empty barrel)
- [x] `lib/main.dart` (app entry point)
- [x] `analysis_options.yaml`
- [x] Platform scaffold (android, ios, macos, linux, windows, web)
- [x] Unified `ai.soliplex.client` identifiers across all platforms
- [x] Local.xcconfig pattern for code signing
- [x] Developer setup documentation

### Step 2: Core — ModuleContribution, ShellConfig & Route Validation (TDD)

- [ ] `ModuleContribution` data class (`routes`, `overrides`)
- [ ] `ShellConfig` immutable data class (`appName`, `theme`, `modules`, `initialRoute`)
- [ ] `ShellConfig.routes` / `ShellConfig.overrides` getters that flatten modules
- [ ] Route validation pure function (recursive tree walk: no duplicate paths with parameterized segment normalization, initial route exists when routes are non-empty, no path shadowing — parameterized sibling before literal sibling is an error); returns list of error descriptions (empty = valid). Note: `RouteBase` is abstract — the walk must type-check `GoRoute` (has `path`), `ShellRoute` (no path, recurse into `routes`), and `StatefulShellRoute` (no path, iterate `branches` then recurse)
- [ ] Tests: valid config, empty modules, duplicate paths (exact and normalized parameterized), missing initial route, nested route validation, path shadowing detection, module flattening

### Step 3: Core — Shell Bootstrap (TDD)

- [ ] `runSoliplexShell()` and `SoliplexShell` widget
- [ ] Validate routes (throw `ArgumentError` on failure) → build GoRouter → ProviderScope with overrides → MaterialApp.router
- [ ] Tests: boot with empty config, boot with test fixture modules, override collection, override precedence (last module wins)

### Step 4: Interfaces

- [ ] `AuthState` abstract class

### Step 5: Barrel Export, Flavor & App Entry Point

- [ ] Fill `soliplex_frontend.dart` with public exports: `ShellConfig`, `ModuleContribution`, `runSoliplexShell`, `AuthState`. Flavors and concrete implementations stay private (`src/`)
- [ ] `UnauthenticatedState` — concrete `AuthState` impl, flavor-private
- [ ] `standard()` flavor function (empty module list initially; design examples show eventual shape)
- [ ] Wire `main.dart` to use `runSoliplexShell` with standard flavor

## Dependencies

```yaml
dependencies:
  flutter: sdk
  flutter_riverpod: ^3.1.0
  go_router: ^17.1.0
  signals: ^6.2.0

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0
```

`soliplex_agent` is NOT a dependency yet — it will be added when the real
agent module is built.

## Verification

After each step:

- `flutter analyze` — no warnings
- `flutter test` — all tests pass

After all steps:

1. App boots cleanly (empty module list is a valid state)
2. Can be imported as a library from a separate Flutter project
3. Test suite verifies composition: multi-module merging, module removal,
   route validation — using test fixtures in `test/`

## What Comes After (not in this plan)

1. Real auth module (OIDC via flutter_appauth)
2. Agent module (wraps soliplex_agent)
3. Real lobby module (room list from backend)
4. Real chat module (agent sessions, message streaming)
5. Inspector module (network inspector UI using soliplex_agent's HttpObserver)
6. Settings, Quiz modules
7. Custom theme abstraction (AppColors/AppTheme — when multiple flavors need it)
