import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_fake_gps/coordinate_store.dart';
import 'package:simple_fake_gps/main.dart';
import 'package:simple_fake_gps/mock_location_platform.dart';

class FakePlatform implements MockLocationPlatform {
  MockLocationSnapshot status = const MockLocationSnapshot(
    isActive: false,
    message: 'Fake location stopped.',
  );
  Object? startError;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<MockLocationSnapshot> getStatus() async => status;

  @override
  Future<MockLocationSnapshot> start(double latitude, double longitude) async {
    startCalls++;
    if (startError case final error?) throw error;
    status = MockLocationSnapshot(
      isActive: true,
      message: 'Publishing $latitude, $longitude.',
    );
    return status;
  }

  @override
  Future<MockLocationSnapshot> stop() async {
    stopCalls++;
    status = const MockLocationSnapshot(
      isActive: false,
      message: 'Fake location stopped.',
    );
    return status;
  }
}

class FakeCoordinateStore implements CoordinateStore {
  FakeCoordinateStore([this.value]);

  SavedCoordinates? value;

  @override
  Future<SavedCoordinates?> load() async => value;

  @override
  Future<void> save(double latitude, double longitude) async {
    value = SavedCoordinates(latitude, longitude);
  }
}

void main() {
  testWidgets('rejects missing and out-of-range coordinates', (tester) async {
    final platform = FakePlatform();
    await tester.pumpWidget(
      SimpleFakeGpsApp(
        platform: platform,
        coordinateStore: FakeCoordinateStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('startButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid latitude.'), findsOneWidget);
    expect(find.text('Enter a valid longitude.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('latitudeField')), '91');
    await tester.enterText(
      find.byKey(const ValueKey('longitudeField')),
      '-181',
    );
    await tester.tap(find.byKey(const ValueKey('startButton')));
    await tester.pumpAndSettle();

    expect(find.text('Latitude must be between -90 and 90.'), findsOneWidget);
    expect(
      find.text('Longitude must be between -180 and 180.'),
      findsOneWidget,
    );
    expect(platform.startCalls, 0);
  });

  testWidgets('restores coordinates and controls active state', (tester) async {
    final platform = FakePlatform();
    final store = FakeCoordinateStore(const SavedCoordinates(51.5074, -0.1278));
    await tester.pumpWidget(
      SimpleFakeGpsApp(platform: platform, coordinateStore: store),
    );
    await tester.pumpAndSettle();

    final latitude = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('latitudeField')),
        matching: find.byType(EditableText),
      ),
    );
    final longitude = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('longitudeField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(latitude.controller.text, '51.5074');
    expect(longitude.controller.text, '-0.1278');

    await tester.tap(find.byKey(const ValueKey('startButton')));
    await tester.pumpAndSettle();
    expect(find.text('Active'), findsOneWidget);
    expect(platform.startCalls, 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final stopButton = find.byKey(const ValueKey('stopButton'));
    final stopControl = tester.widget<OutlinedButton>(stopButton);
    expect(stopControl.onPressed, isNotNull);
    stopControl.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Stopped'), findsOneWidget);
    expect(platform.stopCalls, 1);
  });

  testWidgets('shows actionable native errors', (tester) async {
    final platform = FakePlatform()
      ..startError = PlatformException(
        code: 'MOCK_LOCATION_NOT_ALLOWED',
        message:
            'Select Fake GPS by Horlakz in Developer options → Select mock location app.',
      );
    await tester.pumpWidget(
      SimpleFakeGpsApp(
        platform: platform,
        coordinateStore: FakeCoordinateStore(
          const SavedCoordinates(6.5244, 3.3792),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('startButton')));
    await tester.pumpAndSettle();

    expect(find.text('Action needed'), findsOneWidget);
    expect(
      find.textContaining('Select Fake GPS by Horlakz in Developer options'),
      findsWidgets,
    );
  });
}
