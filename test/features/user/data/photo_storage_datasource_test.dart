import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/user/data/datasources/photo_storage_datasource.dart';

class _MockFirebaseStorage extends Mock implements FirebaseStorage {}

class _MockReference extends Mock implements Reference {}

void main() {
  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.stage);
  });

  group('buildPhotoPath', () {
    // Primary coverage: this is pure and side-effect free, so it exercises
    // the path logic without mocking the Storage SDK. `upload`'s I/O
    // (putData/getDownloadURL) is not mocked below because `UploadTask`
    // extends `Task`, which itself implements `Future<TaskSnapshot>` via a
    // platform delegate — mocktail can't practically stub that as an
    // awaitable, so that path is covered by manual smoke testing instead.
    test('builds a stage-prefixed path', () {
      expect(
        buildPhotoPath('stage', 'u1', 0, 1234),
        'stage/users/u1/photo_0_1234.jpg',
      );
    });

    test('builds a prod-prefixed path', () {
      expect(
        buildPhotoPath('prod', 'u2', 3, 5678),
        'prod/users/u2/photo_3_5678.jpg',
      );
    });
  });

  group('PhotoStorageDataSource.deleteByUrl', () {
    late _MockFirebaseStorage storage;
    late _MockReference reference;
    late PhotoStorageDataSource dataSource;

    setUp(() {
      storage = _MockFirebaseStorage();
      reference = _MockReference();
      dataSource = PhotoStorageDataSource(storage: storage);
    });

    test('resolves the ref from the URL and deletes it', () async {
      const url = 'https://example.com/o/stage%2Fusers%2Fu1%2Fphoto.jpg';
      when(() => storage.refFromURL(url)).thenReturn(reference);
      when(() => reference.delete()).thenAnswer((_) async {});

      await dataSource.deleteByUrl(url);

      verify(() => storage.refFromURL(url)).called(1);
      verify(() => reference.delete()).called(1);
    });

    test('wraps a delete failure in RepositoryWriteException', () async {
      const url = 'https://example.com/o/stage%2Fusers%2Fu1%2Fphoto.jpg';
      when(() => storage.refFromURL(url)).thenReturn(reference);
      when(() => reference.delete()).thenThrow(Exception('boom'));

      await expectLater(
        dataSource.deleteByUrl(url),
        throwsA(isA<RepositoryWriteException>()),
      );
    });
  });
}
