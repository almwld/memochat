package com.memo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.SecureRandom
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Isolated LAN-only message transport. It does not replace Firebase chat and is never
 * started automatically. Both peers must use the same one-time pairing phrase.
 */
class LocalPeerLinkService : Service() {
    companion object {
        const val ACTION_LISTEN = "com.memo.app.local_link.LISTEN"
        const val ACTION_CONNECT = "com.memo.app.local_link.CONNECT"
        const val ACTION_SEND = "com.memo.app.local_link.SEND"
        const val ACTION_STOP = "com.memo.app.local_link.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_PORT = "port"
        const val EXTRA_PAIRING_CODE = "pairing_code"
        const val EXTRA_TEXT = "text"
        const val EXTRA_MESSAGE_ID = "message_id"

        private const val CHANNEL_ID = "memochat_local_link"
        private const val NOTIFICATION_ID = 7412
        private const val DEFAULT_PORT = 39841
        private const val MAX_FRAME = 64 * 1024
        private val events = ConcurrentLinkedQueue<Map<String, Any?>>()
        @Volatile var active = false
            private set
        @Volatile var state = "stopped"
            private set

        fun pollEvents(): List<Map<String, Any?>> {
            val result = mutableListOf<Map<String, Any?>>()
            while (true) result.add(events.poll() ?: break)
            return result
        }

        fun history(context: Context): List<Map<String, Any?>> =
            LocalLinkStore(context).let { store ->
                try { store.history() } finally { store.close() }
            }

        private fun emit(type: String, message: String = "", id: String = "") {
            events.offer(mapOf("type" to type, "message" to message, "id" to id))
        }
    }

    private val executor = Executors.newCachedThreadPool()
    private lateinit var store: LocalLinkStore
    private val random = SecureRandom()
    private val pendingAcks = ConcurrentHashMap<String, Long>()
    private val writeLock = Any()
    @Volatile private var server: ServerSocket? = null
    @Volatile private var socket: Socket? = null
    @Volatile private var output: DataOutputStream? = null
    @Volatile private var pairingCode: String = ""

    override fun onCreate() {
        super.onCreate()
        store = LocalLinkStore(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_LISTEN -> startListening(
                intent.getIntExtra(EXTRA_PORT, DEFAULT_PORT),
                intent.getStringExtra(EXTRA_PAIRING_CODE).orEmpty()
            )
            ACTION_CONNECT -> connectToPeer(
                intent.getStringExtra(EXTRA_HOST).orEmpty(),
                intent.getIntExtra(EXTRA_PORT, DEFAULT_PORT),
                intent.getStringExtra(EXTRA_PAIRING_CODE).orEmpty()
            )
            ACTION_SEND -> sendMessage(
                intent.getStringExtra(EXTRA_TEXT).orEmpty(),
                intent.getStringExtra(EXTRA_MESSAGE_ID) ?: UUID.randomUUID().toString()
            )
            ACTION_STOP -> stopLink()
        }
        return START_NOT_STICKY
    }

    private fun startForegroundNotice(text: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "MemoChat Offline Link", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.setContentTitle("MemoChat Offline Link")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun validCode(code: String): Boolean =
        code.length in 8..64 && code.all { it.isLetterOrDigit() || it in "-_ " }

    private fun startListening(port: Int, code: String) {
        if (!validCode(code) || port !in 1024..65535) {
            emit("error", "رمز الاقتران يجب أن يتكون من 8 إلى 64 حرفًا، والمنفذ صالح.")
            return
        }
        stopNetworkOnly()
        pairingCode = code.trim()
        startForegroundNotice("بانتظار اتصال محلي على المنفذ $port")
        state = "listening"
        active = true
        emit("state", "بانتظار اتصال محلي على المنفذ $port")
        executor.execute {
            try {
                val listener = ServerSocket()
                listener.reuseAddress = true
                listener.bind(InetSocketAddress(port))
                server = listener
                while (active && !listener.isClosed) {
                    val accepted = listener.accept()
                    accepted.tcpNoDelay = true
                    attachSocket(accepted)
                }
            } catch (e: Exception) {
                if (active) fail("تعذر الاستماع محليًا: ${e.localizedMessage ?: "خطأ شبكة"}")
            }
        }
    }

    private fun connectToPeer(host: String, port: Int, code: String) {
        if (host.isBlank() || host.contains("://") || host.any { it.isWhitespace() } ||
            !validCode(code) || port !in 1024..65535) {
            emit("error", "أدخل عنوان IP محليًا صحيحًا ورمز اقتران من 8 إلى 64 حرفًا.")
            return
        }
        stopNetworkOnly()
        pairingCode = code.trim()
        startForegroundNotice("جاري الاتصال بالجهاز المحلي")
        state = "connecting"
        active = true
        emit("state", "جاري الاتصال بـ $host:$port")
        executor.execute {
            try {
                val peer = Socket()
                peer.connect(InetSocketAddress(host, port), 8000)
                peer.tcpNoDelay = true
                attachSocket(peer)
            } catch (e: Exception) {
                fail("تعذر الاتصال بالجهاز: ${e.localizedMessage ?: "تحقق من الشبكة ورمز الاقتران"}")
            }
        }
    }

    @Synchronized
    private fun attachSocket(peer: Socket) {
        if (!active) {
            peer.close()
            return
        }
        try {
            socket?.takeIf { it !== peer }?.close()
            socket = peer
            output = DataOutputStream(peer.getOutputStream())
            state = "connected"
            emit("state", "اتصل جهاز محلي؛ القناة المشفرة جاهزة.")
            val input = DataInputStream(peer.getInputStream())
            executor.execute {
                try {
                    while (active && !peer.isClosed) {
                        val size = input.readInt()
                        if (size !in 1..MAX_FRAME) throw IllegalStateException("حجم رسالة غير صالح")
                        val frame = ByteArray(size)
                        input.readFully(frame)
                        val json = JSONObject(String(decrypt(frame), Charsets.UTF_8))
                        when (json.optString("type")) {
                            "message" -> {
                                val id = json.optString("id")
                                val body = json.optString("text")
                                if (id.isNotBlank() && body.isNotBlank()) {
                                    if (store.saveIncoming(id, body)) emit("received", body, id)
                                    writeJson(JSONObject().put("type", "ack").put("id", id))
                                }
                            }
                            "ack" -> {
                                val id = json.optString("id")
                                pendingAcks.remove(id)
                                store.markDelivered(id)
                                emit("delivered", "استلم الجهاز الآخر الرسالة.", id)
                            }
                        }
                    }
                } catch (e: Exception) {
                    if (active && socket === peer) {
                        state = "disconnected"
                        emit("state", "انقطع الاتصال المحلي؛ أعد الاتصال لإرسال الرسائل.")
                    }
                }
            }
            executor.execute { flushOutbox() }
        } catch (e: Exception) {
            fail("تعذر تهيئة قناة الاتصال: ${e.localizedMessage ?: "خطأ"}")
        }
    }

    private fun sendMessage(text: String, id: String) {
        val body = text.trim()
        if (body.isEmpty() || body.length > 4000) {
            emit("error", "الرسالة فارغة أو أطول من 4000 حرف.")
            return
        }
        store.saveOutgoing(id, body)
        emit("sent", body, id)
        if (state != "connected" || socket?.isConnected != true) {
            emit("state", "حُفظت الرسالة على هذا الهاتف، وستُرسل عند عودة اتصال Memo Offline Link.")
            return
        }
        executor.execute { flushOutbox() }
    }

    private fun flushOutbox() {
        if (state != "connected" || socket?.isConnected != true) return
        for (message in store.pendingOutgoing()) {
            if (state != "connected" || socket?.isConnected != true) return
            if (pendingAcks.putIfAbsent(message.id, System.currentTimeMillis()) != null) continue
            try {
                store.markSending(message.id)
                writeJson(JSONObject().put("type", "message").put("id", message.id)
                    .put("text", message.text).put("sentAt", message.createdAt))
            } catch (e: Exception) {
                pendingAcks.remove(message.id)
                store.markQueued(message.id)
                emit("state", "تعذر إرسال بعض الرسائل؛ حُفظت محليًا لإعادة المحاولة.")
                return
            }
        }
    }

    private fun writeJson(json: JSONObject) {
        val encrypted = encrypt(json.toString().toByteArray(Charsets.UTF_8))
        if (encrypted.size > MAX_FRAME) throw IllegalStateException("الرسالة أكبر من الحد المسموح")
        synchronized(writeLock) {
            val stream = output ?: throw IllegalStateException("القناة غير متصلة")
            stream.writeInt(encrypted.size)
            stream.write(encrypted)
            stream.flush()
        }
    }

    private fun key(): SecretKeySpec {
        val spec = PBEKeySpec(pairingCode.toCharArray(), "MemoChat-Offline-Link-v1".toByteArray(), 120000, 256)
        val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        spec.clearPassword()
        return SecretKeySpec(bytes, "AES")
    }

    private fun encrypt(plain: ByteArray): ByteArray {
        val nonce = ByteArray(12).also { random.nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(), GCMParameterSpec(128, nonce))
        val encrypted = cipher.doFinal(plain)
        return nonce + encrypted
    }

    private fun decrypt(frame: ByteArray): ByteArray {
        if (frame.size < 28) throw IllegalStateException("إطار مشفر غير صالح")
        val nonce = frame.copyOfRange(0, 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, nonce))
        return cipher.doFinal(frame.copyOfRange(12, frame.size))
    }

    private fun fail(message: String) {
        state = "error"
        emit("error", message)
        stopNetworkOnly()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopNetworkOnly() {
        active = false
        try { socket?.close() } catch (_: Exception) {}
        try { server?.close() } catch (_: Exception) {}
        socket = null
        server = null
        output = null
        pendingAcks.clear()
    }

    private fun stopLink() {
        stopNetworkOnly()
        state = "stopped"
        emit("state", "تم إيقاف القناة المحلية.")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopNetworkOnly()
        executor.shutdownNow()
        store.close()
        state = "stopped"
        super.onDestroy()
    }
}
