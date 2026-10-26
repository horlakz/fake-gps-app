package com.horlakz.simple_fake_gps

import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.location.provider.ProviderProperties
import android.os.Build
import android.os.SystemClock

class MockLocationManager(private val locationManager: LocationManager) {
    private var providerRegistered = false

    fun start(latitude: Double, longitude: Double) {
        stop()
        registerProvider()
        locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
        providerRegistered = true
        publish(latitude, longitude)
    }

    fun publish(latitude: Double, longitude: Double) {
        check(providerRegistered) { "The mock GPS provider is not registered." }
        val location = Location(LocationManager.GPS_PROVIDER).apply {
            this.latitude = latitude
            this.longitude = longitude
            altitude = 0.0
            accuracy = 3f
            speed = 0f
            bearing = 0f
            time = System.currentTimeMillis()
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                verticalAccuracyMeters = 3f
                speedAccuracyMetersPerSecond = 0.5f
                bearingAccuracyDegrees = 1f
            }
        }
        locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, location)
    }

    fun stop() {
        if (!providerRegistered) return
        runCatching {
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false)
        }
        runCatching {
            locationManager.removeTestProvider(LocationManager.GPS_PROVIDER)
        }
        providerRegistered = false
    }

    private fun registerProvider() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val properties = ProviderProperties.Builder()
                .setHasNetworkRequirement(false)
                .setHasSatelliteRequirement(true)
                .setHasCellRequirement(false)
                .setHasMonetaryCost(false)
                .setHasAltitudeSupport(true)
                .setHasSpeedSupport(true)
                .setHasBearingSupport(true)
                .setPowerUsage(ProviderProperties.POWER_USAGE_LOW)
                .setAccuracy(ProviderProperties.ACCURACY_FINE)
                .build()
            locationManager.addTestProvider(LocationManager.GPS_PROVIDER, properties)
        } else {
            @Suppress("DEPRECATION")
            locationManager.addTestProvider(
                LocationManager.GPS_PROVIDER,
                false,
                true,
                false,
                false,
                true,
                true,
                true,
                Criteria.POWER_LOW,
                Criteria.ACCURACY_FINE,
            )
        }
    }
}
