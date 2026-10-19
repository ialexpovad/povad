package io.github.ialexpovad.povad

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** Process visibility only; the application-scoped Dart engine owns C++ worker cleanup. */
class PovadBridgeService : Service() {
    companion object {
        private const val CHANNEL_ID = "povad_bridge"
        private const val NOTIFICATION_ID = 9268
        @Volatile private var active = false
        @Volatile private var latestStatus: String? = null

        fun updateNotification(context: Context, status: String) {
            latestStatus = status
            if (!active) return
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, createNotification(context, status))
        }

        private fun createNotification(context: Context, status: String): Notification {
            val open = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pendingOpen = PendingIntent.getActivity(context, 0, open, flags)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context)
            }
            return builder
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("Povad")
                .setContentText(status)
                .setContentIntent(pendingOpen)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build()
        }
    }

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Povad bridge",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val status = latestStatus ?: intent?.getStringExtra("status") ?: "Bridge running"
        try {
            val notification = createNotification(this, status)
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            active = true
        } catch (_: SecurityException) {
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        active = false
        latestStatus = null
        (application as PovadApplication).notifyServiceStopped()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
