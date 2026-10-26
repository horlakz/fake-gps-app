package com.horlakz.simple_fake_gps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class MockLocationService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var mockLocationManager: MockLocationManager
    private var updateRunnable: Runnable? = null
    private var latitude = 0.0
    private var longitude = 0.0

    override fun onCreate() {
        super.onCreate()
        val systemLocationManager = getSystemService(LocationManager::class.java)
        mockLocationManager = MockLocationManager(systemLocationManager)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        latitude = intent?.getDoubleExtra(EXTRA_LATITUDE, Double.NaN) ?: Double.NaN
        longitude = intent?.getDoubleExtra(EXTRA_LONGITUDE, Double.NaN) ?: Double.NaN
        if (!CoordinateValidator.isValid(latitude, longitude)) {
            lastError = "The supplied coordinates are invalid."
            stopSelf()
            return START_NOT_STICKY
        }

        startInForeground(activeNotification())
        startPublishing()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        updateRunnable?.let(handler::removeCallbacks)
        updateRunnable = null
        mockLocationManager.stop()
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startPublishing() {
        updateRunnable?.let(handler::removeCallbacks)
        try {
            mockLocationManager.start(latitude, longitude)
            isRunning = true
            lastError = null
            updateRunnable = object : Runnable {
                override fun run() {
                    try {
                        mockLocationManager.publish(latitude, longitude)
                        handler.postDelayed(this, UPDATE_INTERVAL_MS)
                    } catch (error: Exception) {
                        handleFailure(error)
                    }
                }
            }.also { handler.postDelayed(it, UPDATE_INTERVAL_MS) }
        } catch (error: Exception) {
            handleFailure(error)
        }
    }

    private fun handleFailure(error: Exception) {
        val message = when (error) {
            is SecurityException -> MOCK_ACCESS_MESSAGE
            else -> error.message ?: "Android could not publish the fake location."
        }
        lastError = message
        isRunning = false
        updateRunnable?.let(handler::removeCallbacks)
        updateRunnable = null
        mockLocationManager.stop()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, errorNotification(message))
        @Suppress("DEPRECATION")
        stopForeground(false)
        stopSelf()
    }

    private fun startInForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun activeNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = Intent(this, MockLocationService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopAction = Notification.Action.Builder(
            android.R.drawable.ic_media_pause,
            "Stop",
            stopPendingIntent,
        ).build()

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_location)
            .setContentTitle("Fake location active")
            .setContentText("Publishing $latitude, $longitude")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(stopAction)
            .build()
    }

    private fun errorNotification(message: String): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_location)
            .setContentTitle("Fake location stopped")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .build()

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Fake location status",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows when Fake GPS by Horlakz is publishing a location."
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.horlakz.simple_fake_gps.action.START"
        const val ACTION_STOP = "com.horlakz.simple_fake_gps.action.STOP"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        const val MOCK_ACCESS_MESSAGE =
            "Select Fake GPS by Horlakz in Developer options → Select mock location app, then try again."

        private const val CHANNEL_ID = "mock_location_status"
        private const val NOTIFICATION_ID = 4201
        private const val UPDATE_INTERVAL_MS = 1_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var lastError: String? = null
            private set
    }
}
