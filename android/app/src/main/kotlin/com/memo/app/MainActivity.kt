package com.memo.app

import android.app.NotificationManager
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.net.VpnService
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val fullScreenChannel = "com.memo.app/full_screen_intent"
    private val quickActionsChannel = "com.memo.app/quick_actions"
    private val vpnTunnelChannel = "com.memo.app/vpn_tunnel"
    private val localLinkChannel = "com.memo.app/local_link"
    private val callForegroundServiceChannel = "com.memochat.app/call_foreground_service"
    private var pendingQuickAction: String? = null
    private var pendingVpnStart: Intent? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnTunnelChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> {
                        val intent = VpnService.prepare(this)
                        if (intent == null) {
                            result.success(true)
                        } else {
                            pendingVpnStart = Intent(this, VpnTunnelService::class.java).apply {
                                action = VpnTunnelService.ACTION_START
                                putExtra(VpnTunnelService.EXTRA_HOST, call.argument<String>("host"))
                                putExtra(VpnTunnelService.EXTRA_FINGERPRINT, call.argument<String>("fingerprint"))
                                putExtra(VpnTunnelService.EXTRA_ADDRESS, call.argument<String>("address"))
                                putExtra(VpnTunnelService.EXTRA_ROUTE, call.argument<String>("route"))
                            }
                            startActivityForResult(intent, 7402)
                            result.success(false)
                        }
                    }
                    "status" -> result.success(VpnTunnelService.running)
                    "start" -> {
                        val intent = Intent(this, VpnTunnelService::class.java).apply {
                            action = VpnTunnelService.ACTION_START
                            putExtra(VpnTunnelService.EXTRA_HOST, call.argument<String>("host"))
                            putExtra(VpnTunnelService.EXTRA_FINGERPRINT, call.argument<String>("fingerprint"))
                            putExtra(VpnTunnelService.EXTRA_ADDRESS, call.argument<String>("address"))
                            putExtra(VpnTunnelService.EXTRA_ROUTE, call.argument<String>("route"))
                        }
                        if (android.os.Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    }
                    "stop" -> {
                        startService(Intent(this, VpnTunnelService::class.java).apply { action = VpnTunnelService.ACTION_STOP })
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localLinkChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "listen" -> {
                            val code = call.argument<String>("pairingCode").orEmpty()
                            val port = call.argument<Int>("port") ?: 39841
                            val intent = Intent(this, LocalPeerLinkService::class.java).apply {
                                action = LocalPeerLinkService.ACTION_LISTEN
                                putExtra(LocalPeerLinkService.EXTRA_PAIRING_CODE, code)
                                putExtra(LocalPeerLinkService.EXTRA_PORT, port)
                            }
                            if (android.os.Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        }
                        "connect" -> {
                            val host = call.argument<String>("host").orEmpty()
                            val code = call.argument<String>("pairingCode").orEmpty()
                            val port = call.argument<Int>("port") ?: 39841
                            val intent = Intent(this, LocalPeerLinkService::class.java).apply {
                                action = LocalPeerLinkService.ACTION_CONNECT
                                putExtra(LocalPeerLinkService.EXTRA_HOST, host)
                                putExtra(LocalPeerLinkService.EXTRA_PAIRING_CODE, code)
                                putExtra(LocalPeerLinkService.EXTRA_PORT, port)
                            }
                            if (android.os.Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        }
                        "send" -> {
                            val text = call.argument<String>("text").orEmpty()
                            val intent = Intent(this, LocalPeerLinkService::class.java).apply {
                                action = LocalPeerLinkService.ACTION_SEND
                                putExtra(LocalPeerLinkService.EXTRA_TEXT, text)
                                putExtra(LocalPeerLinkService.EXTRA_MESSAGE_ID, java.util.UUID.randomUUID().toString())
                            }
                            startService(intent)
                            result.success(true)
                        }
                        "stop" -> {
                            startService(Intent(this, LocalPeerLinkService::class.java).apply {
                                action = LocalPeerLinkService.ACTION_STOP
                            })
                            result.success(true)
                        }
                        "status" -> result.success(
                            mapOf("active" to LocalPeerLinkService.active, "state" to LocalPeerLinkService.state)
                        )
                        "poll" -> result.success(LocalPeerLinkService.pollEvents())
                        "addresses" -> {
                            val addresses = mutableListOf<String>()
                            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
                            while (interfaces != null && interfaces.hasMoreElements()) {
                                val network = interfaces.nextElement()
                                if (!network.isUp || network.isLoopback) continue
                                val values = network.inetAddresses
                                while (values.hasMoreElements()) {
                                    val address = values.nextElement()
                                    if (address is java.net.Inet4Address && !address.isLoopbackAddress &&
                                        !address.isLinkLocalAddress) {
                                        addresses.add(address.hostAddress ?: "")
                                    }
                                }
                            }
                            result.success(addresses.distinct())
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("LOCAL_LINK_ERROR", e.localizedMessage ?: "Local Link operation failed", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callForegroundServiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val callId = call.argument<String>("callId")?.trim().orEmpty()
                        val callerName = call.argument<String>("callerName")?.trim().orEmpty()
                        if (callId.isEmpty()) {
                            result.error("INVALID_CALL", "callId is required", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, CallForegroundService::class.java).apply {
                            action = CallForegroundService.ACTION_START
                            putExtra(CallForegroundService.EXTRA_CALL_ID, callId)
                            putExtra(CallForegroundService.EXTRA_CALLER_NAME, callerName)
                        }
                        if (android.os.Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, CallForegroundService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, quickActionsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingAction" -> {
                        val action = pendingQuickAction
                        pendingQuickAction = null
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fullScreenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> {
                        try {
                            if (android.os.Build.VERSION.SDK_INT >= 34) {
                                val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                                result.success(manager.canUseFullScreenIntent())
                            } else {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("CHECK_FAILED", e.message, null)
                        }
                    }
                    "openFullScreenIntentSettings" -> {
                        try {
                            val intent = if (android.os.Build.VERSION.SDK_INT >= 34) {
                                Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT").apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7402) return

        val pending = pendingVpnStart
        pendingVpnStart = null
        if (resultCode != RESULT_OK || pending == null) return

        if (android.os.Build.VERSION.SDK_INT >= 26) {
            startForegroundService(pending)
        } else {
            startService(pending)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingQuickAction = quickActionFromIntent(intent)
        super.onCreate(savedInstanceState)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingQuickAction = quickActionFromIntent(intent)
    }

    private fun quickActionFromIntent(intent: Intent?): String? {
        val data = intent?.data?.toString() ?: return null
        return when (data) {
            "memochat://quick/chat" -> "chat"
            "memochat://quick/compose" -> "compose"
            "memochat://quick/calls" -> "calls"
            "memochat://quick/social" -> "social"
            "memochat://quick/contacts" -> "contacts"
            else -> null
        }
    }
}
