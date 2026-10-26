import 'package:flutter/services.dart';

class SavedCoordinates {
  const SavedCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

abstract class CoordinateStore {
  Future<SavedCoordinates?> load();

  Future<void> save(double latitude, double longitude);
}

class NativeCoordinateStore implements CoordinateStore {
  NativeCoordinateStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.horlakz.simple_fake_gps/mock_location';
  final MethodChannel _channel;

  @override
  Future<SavedCoordinates?> load() async {
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getSavedCoordinates',
    );
    final latitude = (response?['latitude'] as num?)?.toDouble();
    final longitude = (response?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return SavedCoordinates(latitude, longitude);
  }

  @override
  Future<void> save(double latitude, double longitude) async {
    await _channel.invokeMethod<void>('saveCoordinates', <String, double>{
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
