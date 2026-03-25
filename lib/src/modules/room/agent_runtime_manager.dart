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
  final Map<String, AgentRuntime> _runtimes = {};

  /// Returns the cached [AgentRuntime] for [connection], creating it if needed.
  AgentRuntime getRuntime(ServerConnection connection) {
    return _runtimes.putIfAbsent(connection.serverId, () {
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
    });
  }

  /// Disposes all cached runtimes and clears the cache.
  Future<void> dispose() async {
    for (final runtime in _runtimes.values) {
      await runtime.dispose();
    }
    _runtimes.clear();
  }
}
