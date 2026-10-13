import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/queued_write_failures.dart';

void main() {
  test('repeated failures of the same kind are distinct events', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = <QueuedWriteFailure?>[];
    container.listen(queuedWriteFailuresProvider, (_, next) => seen.add(next));
    expect(container.read(queuedWriteFailuresProvider), isNull);

    container.read(queuedWriteFailuresProvider.notifier)
      ..report(QueuedWriteKind.meal)
      ..report(QueuedWriteKind.meal);

    expect(seen, hasLength(2));
    expect(seen.map((e) => e!.kind), everyElement(QueuedWriteKind.meal));
    expect(seen[0]!.id, isNot(seen[1]!.id));
  });
}
