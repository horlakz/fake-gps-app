package com.horlakz.simple_fake_gps

object CoordinateValidator {
    fun isValid(latitude: Double, longitude: Double): Boolean =
        latitude.isFinite() && longitude.isFinite() &&
            latitude in -90.0..90.0 && longitude in -180.0..180.0
}
