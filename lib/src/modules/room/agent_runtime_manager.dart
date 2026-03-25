import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Factory and cache for [AgentRuntime] instances, keyed by server ID.
///
/// Create one manager per app session and pass it to modules that need to
/// spawn agent sessions. Calling [dispose] shuts down all cached runtimes.
class AgentRuntimeManager {
  AgentRuntimeManager({
    required PlatformConstraints platform,
    required ToolRegistryResolver toolRegistryResolver,
    required Logger logger,
  })  : _platform = platform,
        _toolRegistryResolver = toolRegistryResolver,
        _logger = logger;

  final PlatformConstraints _platform;
  final ToolRegistryResolver _toolRegistryResolver;
  final Logger _logger;
  final Map<String, ({ServerConnection connection, AgentRuntime runtime})>
      _cache = {};

  /// Returns the cached [AgentRuntime] for [connection], creating it if
  /// needed.
  ///
  /// If the same server ID appears with a different [ServerConnection]
  /// (e.g., after server removal and re-addition), the stale runtime is
  /// disposed and replaced.
  AgentRuntime getRuntime(ServerConnection connection) {
    final existing = _cache[connection.serverId];
    if (existing != null && identical(existing.connection, connection)) {
      return existing.runtime;
    }
    existing?.runtime.dispose();
    final runtime = _createRuntime(connection);
    _cache[connection.serverId] = (connection: connection, runtime: runtime);
    return runtime;
  }

  AgentRuntime _createRuntime(ServerConnection connection) {
    final llmProvider = AgUiLlmProvider(
      api: connection.api,
      agUiStreamClient: connection.agUiStreamClient,
    );
    return AgentRuntime(
      connection: connection,
      llmProvider: llmProvider,
      toolRegistryResolver: _toolRegistryResolver,
      platform: _platform,
      logger: _logger,
    );
  }

  /// Disposes all cached runtimes and clears the cache.
  Future<void> dispose() async {
    final entries = _cache.values.toList();
    _cache.clear();
    for (final entry in entries) {
      await entry.runtime.dispose();
    }
  }
}
