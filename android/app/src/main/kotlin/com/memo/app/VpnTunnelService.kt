package com.memo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import javax.net.ssl.SSLSocket

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
    private var tunnelSocket: SSLSocket? = null
    private var connectThread: Thread? = null
    private var uplinkThread: Thread? = null
    private var downlinkThread: Thread? = null
    private val stateLock = Any()

    private val magic = byteArrayOf(0x4d, 0x43, 0x56, 0x54)
    private val version: Byte = 1
    private val packetType: Byte = 1
    private val maxPacket = 65535

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
        startForeground(
            7401,
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("MemoChat VPN Tunnel")
                .setContentText("جاري الاتصال ببوابة $host")
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setOngoing(true)
                .build()
        )

        val addressIp = address.substringBefore('/')
        val prefix = address.substringAfter('/', "32").toIntOrNull() ?: 32
        val routeIp = route.substringBefore('/')
        val routePrefix = route.substringAfter('/', "24").toIntOrNull() ?: 24
        if (addressIp.split('.').size != 4 || routeIp.split('.').size != 4) {
            stopTunnel()
            return
        }

        connectThread = Thread({
            try {
                val socket = (javax.net.ssl.SSLSocketFactory.getDefault().createSocket() as SSLSocket)
                if (!protect(socket)) throw IllegalStateException("تعذر حماية قناة النفق من مسار TUN")
                socket.connect(InetSocketAddress(host, 4433), 10000)
                socket.startHandshake()

                val fd = Builder()
                    .setSession("MemoChat Tunnel")
                    .setMtu(1400)
                    .addAddress(addressIp, prefix)
                    .addRoute(routeIp, routePrefix)
                    .setBlocking(false)
                    .establish() ?: throw IllegalStateException("تعذر إنشاء واجهة TUN")

                synchronized(stateLock) {
                    tunnelSocket = socket
                    interfaceFd = fd
                    running = true
                }
                startPacketLoops(fd, socket)
            } catch (_: Exception) {
                synchronized(stateLock) { running = false }
                closeTunnelResources()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }, "MemoChat-Tunnel-Connect")
        connectThread?.start()
    }

    private fun startPacketLoops(fd: ParcelFileDescriptor, socket: SSLSocket) {
        uplinkThread = Thread({
            try {
                val input = DataInputStream(FileInputStream(fd.fileDescriptor))
                val output = DataOutputStream(socket.outputStream)
                val buffer = ByteArray(32768)
                while (running) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (count == 0) continue
                    writeFrame(output, buffer, count)
                }
            } catch (_: Exception) {
            } finally {
                if (running) stopTunnel()
            }
        }, "MemoChat-Tun-Uplink")

        downlinkThread = Thread({
            try {
                val input = DataInputStream(socket.inputStream)
                val output = FileOutputStream(fd.fileDescriptor)
                while (running) {
                    val header = ByteArray(10)
                    input.readFully(header)
                    if (!header.copyOfRange(0, 4).contentEquals(magic)) {
                        throw IllegalStateException("بروتوكول Tunnel غير معروف")
                    }
                    if (header[4] != version || header[5] != packetType) {
                        throw IllegalStateException("إصدار/نوع حزمة Tunnel غير مدعوم")
                    }
                    val length = ByteBuffer.wrap(header, 6, 4).int
                    if (length <= 0 || length > maxPacket) {
                        throw IllegalStateException("حجم حزمة Tunnel غير صالح")
                    }
                    val packet = ByteArray(length)
                    input.readFully(packet)
                    output.write(packet)
                    output.flush()
                }
            } catch (_: Exception) {
            } finally {
                if (running) stopTunnel()
            }
        }, "MemoChat-Tun-Downlink")

        uplinkThread?.start()
        downlinkThread?.start()
    }

    private fun writeFrame(output: DataOutputStream, packet: ByteArray, length: Int) {
        output.write(magic)
        output.writeByte(version.toInt())
        output.writeByte(packetType.toInt())
        output.writeInt(length)
        output.write(packet, 0, length)
        output.flush()
    }

    private fun stopTunnel() {
        synchronized(stateLock) { running = false }
        closeTunnelResources()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun closeTunnelResources() {
        try { tunnelSocket?.close() } catch (_: Exception) {}
        try { interfaceFd?.close() } catch (_: Exception) {}
        tunnelSocket = null
        interfaceFd = null
    }

    override fun onRevoke() {
        stopTunnel()
        super.onRevoke()
    }

    override fun onDestroy() {
        synchronized(stateLock) { running = false }
        closeTunnelResources()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "MemoChat VPN", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }
}
