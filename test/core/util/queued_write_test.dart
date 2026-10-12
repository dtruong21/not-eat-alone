import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/queued_write.dart';

void main() {
  test('an acknowledged write resolves immediately', () {
    fakeAsync((async) {
      var done = false;
      unawaited(settleOrQueue(Future<void>.value()).then((_) => done = true));
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });

  test('a rejection inside the grace period still throws to the caller', () {
    fakeAsync((async) {
      Object? error;
      unawaited(
        settleOrQueue(
          Future<void>.error(StateError('permission-denied')),
        ).then((_) {}, onError: (Object e) => error = e),
      );
      async.flushMicrotasks();
      expect(error, isA<StateError>());
    });
  });

  test('a write still pending after the grace period counts as queued', () {
    fakeAsync((async) {
      final server = Completer<void>();
      var done = false;
      unawaited(settleOrQueue(server.future).then((_) => done = true));

      async.elapse(queuedWriteGrace - const Duration(milliseconds: 1));
      expect(done, isFalse, reason: 'still within the grace period');

      async.elapse(const Duration(milliseconds: 2));
      expect(done, isTrue, reason: 'queued: the UI is released');

      server.complete(); // reconnect: nothing blows up
      async.flushMicrotasks();
    });
  });

  test('an error that arrives after the UI moved on is swallowed (logged)', () {
    fakeAsync((async) {
      final server = Completer<void>();
      var done = false;
      unawaited(settleOrQueue(server.future).then((_) => done = true));
      async.elapse(queuedWriteGrace + const Duration(seconds: 1));
      expect(done, isTrue);

      server.completeError(StateError('rejected after reconnect'));
      async.flushMicrotasks(); // must not surface as an unhandled error
    });
  });

  test('works with writes that return a value (createMeal returns the id)', () {
    fakeAsync((async) {
      var done = false;
      unawaited(settleOrQueue(Future<String>.value('id')).then((_) => done = true));
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });
}
