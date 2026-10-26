package com.horlakz.simple_fake_gps

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CoordinateValidatorTest {
    @Test
    fun acceptsBoundaryAndTypicalCoordinates() {
        assertTrue(CoordinateValidator.isValid(90.0, 180.0))
        assertTrue(CoordinateValidator.isValid(-90.0, -180.0))
        assertTrue(CoordinateValidator.isValid(6.5244, 3.3792))
    }

    @Test
    fun rejectsOutOfRangeAndNonFiniteCoordinates() {
        assertFalse(CoordinateValidator.isValid(90.0001, 0.0))
        assertFalse(CoordinateValidator.isValid(0.0, -180.0001))
        assertFalse(CoordinateValidator.isValid(Double.NaN, 0.0))
        assertFalse(CoordinateValidator.isValid(0.0, Double.POSITIVE_INFINITY))
    }
}
