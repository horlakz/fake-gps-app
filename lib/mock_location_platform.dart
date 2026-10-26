import 'package:flutter/services.dart';

class MockLocationSnapshot {
  const MockLocationSnapshot({
    required this.isActive,
    required this.message,
    this.hasError = false,
  });

  final bool isActive;
  final bool hasError;
  final String message;

  factory MockLocationSnapshot.fromMap(
    Map<Object?, Object?>? value, {
    required String fallbackMessage,
  }) {
    return MockLocationSnapshot(
      isActive: value?['isActive'] == true,
      hasError: value?['status'] == 'error',
      message: value?['message'] as String? ?? fallbackMessage,
    );
  }
}

abstract class MockLocationPlatform {
  Future<MockLocationSnapshot> start(double latitude, double longitude);

  Future<MockLocationSnapshot> stop();

  Future<MockLocationSnapshot> getStatus();
}

class MethodChannelMockLocationPlatform implements MockLocationPlatform {
  MethodChannelMockLocationPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.horlakz.simple_fake_gps/mock_location';
  final MethodChannel _channel;

  @override
  Future<MockLocationSnapshot> start(double latitude, double longitude) async {
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(
      'startMockLocation',
      <String, double>{'latitude': latitude, 'longitude': longitude},
    );
    return MockLocationSnapshot.fromMap(
      response,
      fallbackMessage: 'Fake location active.',
    );
  }

  @override
  Future<MockLocationSnapshot> stop() async {
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(
      'stopMockLocation',
    );
    return MockLocationSnapshot.fromMap(
      response,
      fallbackMessage: 'Fake location stopped.',
    );
  }

  @override
  Future<MockLocationSnapshot> getStatus() async {
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getStatus',
    );
    return MockLocationSnapshot.fromMap(
      response,
      fallbackMessage: 'Fake location stopped.',
    );
  }
}
