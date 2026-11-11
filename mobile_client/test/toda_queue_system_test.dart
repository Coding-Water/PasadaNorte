import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/toda_queue_service.dart';
import 'package:mobile_client/features/driver/views/toda_queue_screen.dart';

void main() {
  setUp(() {
    TodaQueueService.resetQueuesForTesting();
  });

  group('TodaQueueService Dynamic FIFO Queue Logic', () {
    test('Initial state: Eduardo is Rank #1 in term_01', () {
      final rank = TodaQueueService.getCurrentDriverRank('term_01', driverName: 'Eduardo');
      expect(rank, 1);
      expect(TodaQueueService.isDriverQueued('term_01', driverName: 'Eduardo'), isTrue);

      final queue = TodaQueueService.getTerminalQueue('term_01', driverName: 'Eduardo');
      expect(queue.length, 5);
      expect(queue.first.driverName, contains('Eduardo'));
      expect(queue.first.isCurrentDriver, isTrue);
    });

    test('Trip Acceptance: Dequeueing driver removes them and shifts line forward', () {
      // Driver accepts passenger and departs terminal
      TodaQueueService.dequeueDriverForTrip('term_01', 'Eduardo');

      // Eduardo is no longer queued
      final rank = TodaQueueService.getCurrentDriverRank('term_01', driverName: 'Eduardo');
      expect(rank, 0);
      expect(TodaQueueService.isDriverQueued('term_01', driverName: 'Eduardo'), isFalse);

      // Remaining queue has shifted: Arturo is now Rank #1
      final queue = TodaQueueService.getTerminalQueue('term_01', driverName: 'Eduardo');
      expect(queue.length, 4);
      expect(queue[0].rank, 1);
      expect(queue[0].driverName, 'Arturo Domingo');
      expect(queue[0].status, contains('Next to Board'));
      expect(queue[1].rank, 2);
      expect(queue[1].driverName, 'Nestor Valdez');
    });

    test('Trip Return: Enqueueing driver joins at tail of FIFO queue (no line cutting)', () {
      // Dequeue first
      TodaQueueService.dequeueDriverForTrip('term_01', 'Eduardo');
      expect(TodaQueueService.getTerminalQueue('term_01').length, 4);

      // Driver returns from trip and arrives at terminal geofence
      final assignedRank = TodaQueueService.enqueueDriverAtTail(
        'term_01',
        'Eduardo "Manong Eddie" Castro',
        '#0042',
      );

      // Assigned rank must be at the end of the line (Rank #5)
      expect(assignedRank, 5);

      final queue = TodaQueueService.getTerminalQueue('term_01', driverName: 'Eduardo');
      expect(queue.length, 5);
      expect(queue.last.rank, 5);
      expect(queue.last.bodyNumber, '#0042');
      expect(queue.last.isCurrentDriver, isTrue);
      expect(queue.last.status, contains('Just Queued'));
    });
  });

  group('TodaQueueScreen Full-Screen Board Widget Tests', () {
    testWidgets('Renders Terminal dropdown, driver status, and live FIFO list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TodaQueueScreen(
            driverName: 'Eduardo "Manong Eddie" Castro',
            initialTerminalId: 'term_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('TODA Digital Pila Queue Board'), findsOneWidget);

      // Verify Terminal Selector & Geofence Specs
      expect(find.textContaining('SELECT TODA TERMINAL BAY'), findsOneWidget);
      expect(find.textContaining('CENTRAL-TODA'), findsOneWidget);

      // Verify Driver Status Banner (Rank #1 initially)
      expect(find.text('DISPATCH PRIORITY #1'), findsOneWidget);
      expect(find.textContaining('Position 1 of 5'), findsOneWidget);

      // Verify Live Dispatch List Units
      expect(find.text('Live FIFO Terminal Line'), findsOneWidget);
      expect(find.textContaining('Eduardo "Manong Eddie" Castro (YOU)'), findsOneWidget);
      expect(find.text('Arturo Domingo'), findsOneWidget);
      expect(find.text('#0042'), findsOneWidget);
      expect(find.text('#0012'), findsOneWidget);

      // Verify Metrics and Ordinance compliance (scroll into view)
      await tester.scrollUntilVisible(find.text('Terminal Bay Metrics'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Terminal Bay Metrics'), findsOneWidget);
      expect(find.textContaining('Laoag City Ordinance No. 2023-005 Compliance'), findsOneWidget);
    });

    testWidgets('Renders NOT QUEUED banner when driver is en route/unassigned', (tester) async {
      // Dequeue driver first so rank is 0
      TodaQueueService.dequeueDriverForTrip('term_01', 'Eduardo');

      await tester.pumpWidget(
        const MaterialApp(
          home: TodaQueueScreen(
            driverName: 'Eduardo "Manong Eddie" Castro',
            initialTerminalId: 'term_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should reflect not queued status
      expect(find.text('NOT QUEUED • EN ROUTE / OUTSIDE BAY'), findsOneWidget);
      expect(find.textContaining('You are not currently in the Laoag Central Terminal'), findsOneWidget);
    });
  });
}
