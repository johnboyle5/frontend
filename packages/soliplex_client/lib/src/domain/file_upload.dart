import 'package:meta/meta.dart';

/// A file persisted in the backend's upload directory for a room or
/// thread.
///
/// Returned by `GET /uploads/{room_id}` and
/// `GET /uploads/{room_id}/{thread_id}`.
@immutable
class FileUpload {
  /// Creates a file upload entry.
  const FileUpload({
    required this.filename,
    required this.url,
  });

  /// User-visible filename as stored by the backend.
  final String filename;

  /// URL for downloading the file.
  final Uri url;

  /// Creates a copy of this entry with the given fields replaced.
  FileUpload copyWith({
    String? filename,
    Uri? url,
  }) {
    return FileUpload(
      filename: filename ?? this.filename,
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileUpload &&
        other.filename == filename &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(filename, url);

  @override
  String toString() => 'FileUpload(filename: $filename, url: $url)';
}
