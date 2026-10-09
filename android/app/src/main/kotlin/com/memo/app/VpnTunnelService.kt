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
import java.security.MessageDigest
import javax.net.ssl.SSLContext
import org.json.JSONObject
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

class VpnTunnelService : VpnService() {
    companion object {
        const val ACTION_START = "com.memo.app.vpn.START"
        const val ACTION_STOP = "com.memo.app.vpn.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_FINGERPRINT = "fingerprint"
        const val EXTRA_ADDRESS = "address"
        const val EXTRA_ROUTE = "route"
        const val EXTRA_PEER_ID = "peerId"
        const val EXTRA_SHARED_SECRET = "sharedSecret"
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
    private var generation = 0

    private val magic = byteArrayOf(0x4d, 0x43, 0x56, 0x54)
    private val version: Byte = 1
    private val packetType: Byte = 1
    private val maxPacket = 65535

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopTunnel()
            ACTION_START -> startTunnel(
                intent.getStringExtra(EXTRA_HOST).orEmpty(),
                intent.getStringExtra(EXTRA_FINGERPRINT).orEmpty(),
                intent.getStringExtra(EXTRA_PEER_ID).orEmpty(),
                intent.getStringExtra(EXTRA_SHARED_SECRET).orEmpty(),
                intent.getStringExtra(EXTRA_ADDRESS) ?: "10.254.0.2/32",
                intent.getStringExtra(EXTRA_ROUTE) ?: "10.254.0.0/24"
            )
        }
        return START_STICKY
    }

    private fun startTunnel(host: String, fingerprint: String, peerId: String, sharedSecret: String, address: String, route: String) {
        val attempt = synchronized(stateLock) {
            generation += 1
            running = false
            generation
        }
        // Replacing a tunnel must close old resources without calling stopSelf(),
        // otherwise Android may destroy the service immediately after a new start.
        closeTunnelResources()
        connectThread?.interrupt()
        uplinkThread?.interrupt()
        downlinkThread?.interrupt()

        if (host.isBlank() || peerId.isBlank() || sharedSecret.length < 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

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
        if (addressIp.split('.').size != 4 || routeIp.split('.').size != 4 ||
            prefix !in 0..32 || routePrefix !in 0..32) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        connectThread = Thread({
            var candidateSocket: SSLSocket? = null
            var candidateFd: ParcelFileDescriptor? = null
            try {
                val socket = createSslSocket(host, fingerprint)
                candidateSocket = socket
                if (!protect(socket)) throw IllegalStateException("تعذر حماية قناة النفق من مسار TUN")
                socket.connect(InetSocketAddress(host, 4433), 10000)
                socket.soTimeout = 10000
                socket.startHandshake()
                registerPeer(socket, peerId, sharedSecret, addressIp)
                socket.soTimeout = 0

                val fd = Builder()
                    .setSession("MemoChat Tunnel")
                    .setMtu(1400)
                    .addAddress(addressIp, prefix)
                    .addRoute(routeIp, routePrefix)
                    .setBlocking(true)
                    .establish() ?: throw IllegalStateException("تعذر إنشاء واجهة TUN")
                candidateFd = fd

                synchronized(stateLock) {
                    if (generation != attempt) {
                        try { fd.close() } catch (_: Exception) {}
                        try { socket.close() } catch (_: Exception) {}
                        return@Thread
                    }
                    tunnelSocket = socket
                    interfaceFd = fd
                    running = true
                }
                startPacketLoops(fd, socket, attempt)
            } catch (error: Exception) {
                val shouldStop = synchronized(stateLock) {
                    if (generation != attempt) {
                        false
                    } else {
                        running = false
                        if (tunnelSocket === candidateSocket) tunnelSocket = null
                        if (interfaceFd === candidateFd) interfaceFd = null
                        true
                    }
                }
                try { candidateSocket?.close() } catch (_: Exception) {}
                try { candidateFd?.close() } catch (_: Exception) {}
                if (shouldStop) {
                    synchronized(stateLock) {
                        if (generation == attempt) {
                            stopForeground(STOP_FOREGROUND_REMOVE)
                            stopSelf()
                        }
                    }
                }
            }
        }, "MemoChat-Tunnel-Connect")
        connectThread?.start()
    }

    private fun isCurrentGeneration(attempt: Int): Boolean =
        synchronized(stateLock) { generation == attempt }

    private fun createSslSocket(host: String, fingerprint: String): SSLSocket {
        val normalizedPin = normalizeFingerprint(fingerprint)
        if (normalizedPin.isEmpty()) {
            val socket = (javax.net.ssl.SSLSocketFactory.getDefault().createSocket() as SSLSocket)
            socket.sslParameters = socket.sslParameters.apply {
                endpointIdentificationAlgorithm = "HTTPS"
            }
            return socket
        }

        val base = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        base.init(null as java.security.KeyStore?)
        val delegate = base.trustManagers.filterIsInstance<X509TrustManager>().first()
        val pinned = object : X509TrustManager {
            override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> =
                delegate.acceptedIssuers

            override fun checkClientTrusted(
                chain: Array<java.security.cert.X509Certificate>,
                authType: String
            ) = delegate.checkClientTrusted(chain, authType)

            override fun checkServerTrusted(
                chain: Array<java.security.cert.X509Certificate>,
                authType: String
            ) {
                var trustedBySystem = false
                try {
                    delegate.checkServerTrusted(chain, authType)
                    trustedBySystem = true
                } catch (_: Exception) {
                    // A private/self-signed gateway may not be in Android's CA store.
                }
                val matchesPin = chain.any { certificate ->
                    sha256(certificate.encoded) == normalizedPin
                }
                if (!matchesPin) {
                    if (trustedBySystem) {
                        throw java.security.cert.CertificateException("Gateway certificate pin mismatch")
                    }
                    throw java.security.cert.CertificateException("Gateway certificate is not trusted or pinned")
                }
            }
        }

        val context = SSLContext.getInstance("TLS")
        context.init(null, arrayOf(pinned), null)
        val socket = context.socketFactory.createSocket() as SSLSocket
        socket.sslParameters = socket.sslParameters.apply {
            // Certificate pinning is the identity check for private gateways.
            endpointIdentificationAlgorithm = ""
        }
        return socket
    }

    private fun normalizeFingerprint(value: String): String =
        value.replace(":", "").replace(" ", "").trim().lowercase()

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }

    private fun startPacketLoops(fd: ParcelFileDescriptor, socket: SSLSocket, attempt: Int) {
        uplinkThread = Thread({
            try {
                val input = DataInputStream(FileInputStream(fd.fileDescriptor))
                val output = DataOutputStream(socket.outputStream)
                val buffer = ByteArray(32768)
                while (running && isCurrentGeneration(attempt)) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (count == 0) continue
                    writeFrame(output, packetType, buffer, count)
                }
            } catch (_: Exception) {
            } finally {
                if (running && isCurrentGeneration(attempt)) stopTunnel()
            }
        }, "MemoChat-Tun-Uplink")

        downlinkThread = Thread({
            try {
                val input = DataInputStream(socket.inputStream)
                val output = FileOutputStream(fd.fileDescriptor)
                while (running && isCurrentGeneration(attempt)) {
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
                if (running && isCurrentGeneration(attempt)) stopTunnel()
            }
        }, "MemoChat-Tun-Downlink")

        uplinkThread?.start()
        downlinkThread?.start()
    }

    private fun registerPeer(socket: SSLSocket, peerId: String, sharedSecret: String, address: String) {
        val output = DataOutputStream(socket.outputStream)
        val input = DataInputStream(socket.inputStream)
        val request = JSONObject()
            .put("peerId", peerId)
            .put("secret", sharedSecret)
            .put("address", address)
            .toString()
            .toByteArray(Charsets.UTF_8)
        writeFrame(output, 2.toByte(), request, request.size)

        val header = ByteArray(10)
        input.readFully(header)
        if (!header.copyOfRange(0, 4).contentEquals(magic) ||
            header[4] != version || header[5] != 3.toByte()) {
            throw IllegalStateException("استجابة تسجيل Tunnel غير صالحة")
        }
        val length = ByteBuffer.wrap(header, 6, 4).int
        if (length <= 0 || length > 4096) {
            throw IllegalStateException("حجم استجابة تسجيل Tunnel غير صالح")
        }
        val response = ByteArray(length)
        input.readFully(response)
        val acknowledgement = JSONObject(String(response, Charsets.UTF_8))
        if (!acknowledgement.optBoolean("ok", false)) {
            throw IllegalStateException(acknowledgement.optString("message", "رفضت بوابة Tunnel تسجيل الجهاز"))
        }
    }

    private fun writeFrame(output: DataOutputStream, type: Byte, packet: ByteArray, length: Int) {
        output.write(magic)
        output.writeByte(version.toInt())
        output.writeByte(type.toInt())
        output.writeInt(length)
        output.write(packet, 0, length)
        output.flush()
    }

    private fun stopTunnel() {
        synchronized(stateLock) {
            generation += 1
            running = false
        }
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
        synchronized(stateLock) {
            generation += 1
            running = false
        }
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
