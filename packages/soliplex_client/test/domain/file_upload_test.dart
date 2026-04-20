import 'package:soliplex_client/src/domain/file_upload.dart';
import 'package:test/test.dart';

void main() {
  group('FileUpload', () {
    group('equality', () {
      test('equals by filename and url', () {
        final a = FileUpload(
          filename: 'report.pdf',
          url: Uri.parse('https://example.com/rooms/r/uploads/report.pdf'),
        );
        final b = FileUpload(
          filename: 'report.pdf',
          url: Uri.parse('https://example.com/rooms/r/uploads/report.pdf'),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equals with different filename', () {
        final a = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/a'),
        );
        final b = FileUpload(
          filename: 'b.pdf',
          url: Uri.parse('https://example.com/a'),
        );

        expect(a, isNot(equals(b)));
      });

      test('not equals with different url', () {
        final a = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/a'),
        );
        final b = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/b'),
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('overrides filename', () {
        final a = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/a'),
        );
        final b = a.copyWith(filename: 'b.pdf');

        expect(b.filename, 'b.pdf');
        expect(b.url, a.url);
      });

      test('overrides url', () {
        final a = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/a'),
        );
        final b = a.copyWith(url: Uri.parse('https://example.com/b'));

        expect(b.filename, a.filename);
        expect(b.url.toString(), 'https://example.com/b');
      });

      test('no args returns equal instance', () {
        final a = FileUpload(
          filename: 'a.pdf',
          url: Uri.parse('https://example.com/a'),
        );

        expect(a.copyWith(), equals(a));
      });
    });
  });
}
