package com.paystrater.flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Opens links (the Paystrater app, a wallet, the browser) and the share sheet, instead of url_launcher. */
class PaystraterFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.paystrater.flutter/links")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUrl" -> {
                val url = call.argument<String>("url") ?: return result.success(false)
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                result.success(start(intent))
            }
            "canOpenUrl" -> {
                val url = call.argument<String>("url") ?: return result.success(false)
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                result.success(intent.resolveActivity(context.packageManager) != null)
            }
            "share" -> {
                val text = call.argument<String>("text") ?: return result.success(null)
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                start(Intent.createChooser(send, null))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(intent: Intent): Boolean {
        val from = activity
        if (from == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            (from ?: context).startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
