package com.memo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor

class VpnTunnelService : VpnService() {
    companion object {
        const val ACTION_START = "com.memo.app.vpn.START"
        const val ACTION_STOP = "com.memo.app.vpn.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_ADDRESS = "address"
        const val EXTRA_ROUTE = "route"
        private const val CHANNEL_ID = "memochat_vpn"
        @Volatile var running = false
            private set
    }

    private var interfaceFd: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopTunnel()
            ACTION_START -> startTunnel(
                intent.getStringExtra(EXTRA_HOST).orEmpty(),
                intent.getStringExtra(EXTRA_ADDRESS) ?: "10.254.0.2/32",
                intent.getStringExtra(EXTRA_ROUTE) ?: "10.254.0.0/24"
            )
        }
        return START_STICKY
    }

    private fun startTunnel(host: String, address: String, route: String) {
        stopTunnel()
        if (host.isBlank()) return
        createNotificationChannel()
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("MemoChat VPN Tunnel")
            .setContentText("واجهة TUN نشطة — البوابة $host")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setOngoing(true)
            .build()
        startForeground(7401, notification)

        val addressIp = address.substringBefore('/')
        val prefix = address.substringAfter('/', "32").toIntOrNull() ?: 32
        if (addressIp.split('.').size != 4) return
        val routeIp = route.substringBefore('/')
        val routePrefix = route.substringAfter('/', "24").toIntOrNull() ?: 24

        interfaceFd = Builder()
            .setSession("MemoChat Tunnel")
            .setMtu(1400)
            .addAddress(addressIp, prefix)
            .addRoute(routeIp, routePrefix)
            .setBlocking(false)
            .establish()
        running = interfaceFd != null
    }

    private fun stopTunnel() {
        running = false
        try { interfaceFd?.close() } catch (_: Exception) {}
        interfaceFd = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "MemoChat VPN", NotificationManager.IMPORTANCE_LOW
            ))
        }
    }

    override fun onDestroy() {
        running = false
        try { interfaceFd?.close() } catch (_: Exception) {}
        interfaceFd = null
        super.onDestroy()
    }
}
