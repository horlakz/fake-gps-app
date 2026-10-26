import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coordinate_store.dart';
import 'mock_location_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SimpleFakeGpsApp());
}

class SimpleFakeGpsApp extends StatelessWidget {
  SimpleFakeGpsApp({
    super.key,
    MockLocationPlatform? platform,
    CoordinateStore? coordinateStore,
  }) : platform = platform ?? MethodChannelMockLocationPlatform(),
       coordinateStore = coordinateStore ?? NativeCoordinateStore();

  final MockLocationPlatform platform;
  final CoordinateStore coordinateStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fake GPS by Horlakz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: FakeGpsHomePage(
        platform: platform,
        coordinateStore: coordinateStore,
      ),
    );
  }
}

enum ScreenStatus { checking, inactive, active, error }

class FakeGpsHomePage extends StatefulWidget {
  const FakeGpsHomePage({
    super.key,
    required this.platform,
    required this.coordinateStore,
  });

  final MockLocationPlatform platform;
  final CoordinateStore coordinateStore;

  @override
  State<FakeGpsHomePage> createState() => _FakeGpsHomePageState();
}

class _FakeGpsHomePageState extends State<FakeGpsHomePage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  ScreenStatus _status = ScreenStatus.checking;
  String _statusMessage = 'Checking the Android mock-location service…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      _refreshStatus();
    }
  }

  Future<void> _initialise() async {
    try {
      final saved = await widget.coordinateStore.load();
      if (!mounted) return;
      if (saved != null) {
        _latitudeController.text = saved.latitude.toString();
        _longitudeController.text = saved.longitude.toString();
      }
      await _refreshStatus();
    } catch (error) {
      if (!mounted) return;
      _setError('Could not initialise the app: ${_friendlyError(error)}');
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final snapshot = await widget.platform.getStatus();
      if (!mounted) return;
      setState(() {
        _status = snapshot.hasError
            ? ScreenStatus.error
            : snapshot.isActive
            ? ScreenStatus.active
            : ScreenStatus.inactive;
        _statusMessage = snapshot.message;
      });
    } catch (error) {
      if (!mounted) return;
      _setError(_friendlyError(error));
    }
  }

  String? _validateLatitude(String? value) {
    final latitude = double.tryParse(value?.trim() ?? '');
    if (latitude == null) return 'Enter a valid latitude.';
    if (latitude < -90 || latitude > 90) {
      return 'Latitude must be between -90 and 90.';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final longitude = double.tryParse(value?.trim() ?? '');
    if (longitude == null) return 'Enter a valid longitude.';
    if (longitude < -180 || longitude > 180) {
      return 'Longitude must be between -180 and 180.';
    }
    return null;
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final latitude = double.parse(_latitudeController.text.trim());
    final longitude = double.parse(_longitudeController.text.trim());

    setState(() => _busy = true);
    try {
      await widget.coordinateStore.save(latitude, longitude);
      final snapshot = await widget.platform.start(latitude, longitude);
      if (!mounted) return;
      setState(() {
        _status = ScreenStatus.active;
        _statusMessage = snapshot.message;
      });
      _showMessage('Fake location started.');
    } catch (error) {
      if (!mounted) return;
      _setError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      final snapshot = await widget.platform.stop();
      if (!mounted) return;
      setState(() {
        _status = ScreenStatus.inactive;
        _statusMessage = snapshot.message;
      });
      _showMessage('Fake location stopped.');
    } catch (error) {
      if (!mounted) return;
      _setError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String message) {
    setState(() {
      _status = ScreenStatus.error;
      _statusMessage = message;
    });
    _showMessage(message);
  }

  String _friendlyError(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'Android rejected the mock-location request.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _status == ScreenStatus.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake GPS by Horlakz'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Set a fixed test location',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Other apps may use this coordinate while the foreground '
              'service is active.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _StatusCard(status: _status, message: _statusMessage),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Coordinates',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('latitudeField'),
                        controller: _latitudeController,
                        enabled: !_busy && !isActive,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g. 51.5074',
                          prefixIcon: Icon(Icons.north),
                        ),
                        validator: _validateLatitude,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('longitudeField'),
                        controller: _longitudeController,
                        enabled: !_busy && !isActive,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g. -0.1278',
                          prefixIcon: Icon(Icons.east),
                        ),
                        validator: _validateLongitude,
                        onFieldSubmitted: (_) {
                          if (!isActive && !_busy) _start();
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const ValueKey('startButton'),
                        onPressed: _busy || isActive ? null : _start,
                        icon: _busy && !isActive
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text('Start fake location'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('stopButton'),
                        onPressed: _busy || !isActive ? null : _stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop fake location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SetupCard(),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.message});

  final ScreenStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (status) {
      ScreenStatus.checking => (
        Theme.of(context).colorScheme.secondary,
        Icons.sync,
        'Checking status',
      ),
      ScreenStatus.inactive => (Colors.blueGrey, Icons.location_off, 'Stopped'),
      ScreenStatus.active => (
        Colors.green.shade700,
        Icons.my_location,
        'Active',
      ),
      ScreenStatus.error => (
        Colors.red.shade700,
        Icons.error_outline,
        'Action needed',
      ),
    };

    return Semantics(
      liveRegion: true,
      label: '$title. $message',
      child: Card(
        key: const ValueKey('statusCard'),
        color: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One-time phone setup',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text('1. Enable Developer options on your phone.'),
            const SizedBox(height: 6),
            const Text('2. Open Developer options → Select mock location app.'),
            const SizedBox(height: 6),
            const Text('3. Choose Fake GPS by Horlakz, then return here.'),
          ],
        ),
      ),
    );
  }
}
