import 'package:soliplex_agent/src/runtime/session_extension.dart';

/// An extension that can respond to tool approval requests.
///
/// Subclass this in the application layer (e.g. `HumanApprovalExtension`) to
/// intercept calls to `AgentSession.requestApproval` and surface them as
/// reactive state that the UI can observe and respond to.
///
/// When an instance of this extension is registered with a session,
/// `AgentSession.requestApproval` delegates to [requestApproval]. When no
/// extension is registered, `AgentSession.requestApproval` returns `false`
/// (deny by default).
///
/// Tool approval is a single policy decision per session — one user, one
/// allow-or-deny answer — so a flavor picks exactly one implementation
/// (human-prompting, automated, policy-driven, ...). All subclasses share
/// the [namespace] `tool_approval` so registering two instances on the same
/// session is rejected at construction by `SessionCoordinator`'s namespace
/// uniqueness check. Without the shared namespace,
/// `SessionCoordinator.getExtension<T>()` would silently return only the
/// first registered instance.
abstract class ToolApprovalExtension extends SessionExtension {
  ToolApprovalExtension() {
    assert(
      namespace == 'tool_approval',
      'ToolApprovalExtension subclasses MUST NOT override namespace; the '
      'shared "tool_approval" namespace is what enables single-instance '
      'enforcement via SessionCoordinator.',
    );
  }

  @override
  String get namespace => 'tool_approval';

  /// Requests user consent for the given tool call.
  ///
  /// Returns `true` to proceed with execution, `false` to deny. The session
  /// uses a synchronous cancel-token check before delegating here; the
  /// extension is responsible for resolving any pending request to `false`
  /// when the session is cancelled mid-request (typically via a
  /// `cancelToken.whenCancelled` listener registered in [onAttach]).
  Future<bool> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  });
}
