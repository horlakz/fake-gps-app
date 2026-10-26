package com.horlakz.simple_fake_gps

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingStart: PendingStart? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::handleMethodCall)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST_CODE) return

        val request = pendingStart ?: return
        pendingStart = null
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            request.result.error(
                "LOCATION_PERMISSION_DENIED",
                "Allow precise location access so Android can run the location foreground service.",
                null,
            )
            return
        }
        startService(request.latitude, request.longitude, request.result)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMockLocation" -> handleStart(call, result)
            "stopMockLocation" -> handleStop(result)
            "getStatus" -> result.success(currentStatus())
            "getSavedCoordinates" -> result.success(savedCoordinates())
            "saveCoordinates" -> saveCoordinates(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Number>("latitude")?.toDouble()
        val longitude = call.argument<Number>("longitude")?.toDouble()
        if (latitude == null || longitude == null ||
            !CoordinateValidator.isValid(latitude, longitude)
        ) {
            result.error(
                "INVALID_COORDINATES",
                "Latitude must be -90 to 90 and longitude must be -180 to 180.",
                null,
            )
            return
        }

        val missingPermissions = mutableListOf<String>()
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            missingPermissions += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            missingPermissions += Manifest.permission.POST_NOTIFICATIONS
        }

        if (missingPermissions.isNotEmpty()) {
            pendingStart?.result?.error(
                "REQUEST_REPLACED",
                "A newer start request replaced this one.",
                null,
            )
            pendingStart = PendingStart(latitude, longitude, result)
            requestPermissions(missingPermissions.toTypedArray(), PERMISSION_REQUEST_CODE)
            return
        }

        startService(latitude, longitude, result)
    }

    private fun startService(
        latitude: Double,
        longitude: Double,
        result: MethodChannel.Result,
    ) {
        val locationManager = getSystemService(LocationManager::class.java)
        val locationEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            locationManager.isLocationEnabled
        } else {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        }
        if (!locationEnabled) {
            result.error(
                "LOCATION_DISABLED",
                "Turn on Location in Android Settings, then try again.",
                null,
            )
            return
        }
        if (!isMockLocationAllowed()) {
            result.error(
                "MOCK_LOCATION_NOT_ALLOWED",
                MockLocationService.MOCK_ACCESS_MESSAGE,
                null,
            )
            return
        }

        val intent = Intent(this, MockLocationService::class.java).apply {
            action = MockLocationService.ACTION_START
            putExtra(MockLocationService.EXTRA_LATITUDE, latitude)
            putExtra(MockLocationService.EXTRA_LONGITUDE, longitude)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(
                mapOf(
                    "isActive" to true,
                    "status" to "active",
                    "message" to "Publishing $latitude, $longitude.",
                ),
            )
        } catch (error: SecurityException) {
            result.error(
                "SERVICE_NOT_ALLOWED",
                error.message ?: "Android did not allow the location service to start.",
                null,
            )
        } catch (error: Exception) {
            result.error(
                "SERVICE_START_FAILED",
                error.message ?: "The fake-location service could not start.",
                null,
            )
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        stopService(Intent(this, MockLocationService::class.java))
        result.success(
            mapOf(
                "isActive" to false,
                "status" to "inactive",
                "message" to "Fake location stopped. Android GPS is available again.",
            ),
        )
    }

    private fun currentStatus(): Map<String, Any> {
        val error = MockLocationService.lastError
        return when {
            MockLocationService.isRunning -> mapOf(
                "isActive" to true,
                "status" to "active",
                "message" to "Fake location is active in the background.",
            )
            error != null -> mapOf(
                "isActive" to false,
                "status" to "error",
                "message" to error,
            )
            else -> mapOf(
                "isActive" to false,
                "status" to "inactive",
                "message" to "Fake location is stopped.",
            )
        }
    }

    private fun savedCoordinates(): Map<String, Double>? {
        val preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
        val latitude = preferences.getString(PREFERENCE_LATITUDE, null)?.toDoubleOrNull()
        val longitude = preferences.getString(PREFERENCE_LONGITUDE, null)?.toDoubleOrNull()
        if (latitude == null || longitude == null ||
            !CoordinateValidator.isValid(latitude, longitude)
        ) {
            return null
        }
        return mapOf("latitude" to latitude, "longitude" to longitude)
    }

    private fun saveCoordinates(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Number>("latitude")?.toDouble()
        val longitude = call.argument<Number>("longitude")?.toDouble()
        if (latitude == null || longitude == null ||
            !CoordinateValidator.isValid(latitude, longitude)
        ) {
            result.error("INVALID_COORDINATES", "The coordinates cannot be saved.", null)
            return
        }
        getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
            .edit()
            .putString(PREFERENCE_LATITUDE, latitude.toString())
            .putString(PREFERENCE_LONGITUDE, longitude.toString())
            .apply()
        result.success(null)
    }

    private fun isMockLocationAllowed(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                Process.myUid(),
                packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private data class PendingStart(
        val latitude: Double,
        val longitude: Double,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL_NAME =
            "com.horlakz.simple_fake_gps/mock_location"
        private const val PERMISSION_REQUEST_CODE = 7301
        private const val PREFERENCES_NAME = "simple_fake_gps"
        private const val PREFERENCE_LATITUDE = "last_latitude"
        private const val PREFERENCE_LONGITUDE = "last_longitude"
    }
}
