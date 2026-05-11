package com.example.lounge_owner_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
	private val channelName = "lounge_owner_app/system_time_updates"
	private var eventSink: EventChannel.EventSink? = null
	private val mainHandler = Handler(Looper.getMainLooper())

	private val timeChangeReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context?, intent: Intent?) {
			emitCurrentTime()
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setStreamHandler(
				object : EventChannel.StreamHandler {
					override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
						eventSink = events
						registerReceiver()
						emitCurrentTime()
					}

					override fun onCancel(arguments: Any?) {
						unregisterReceiver()
						eventSink = null
					}
				},
			)
	}

	override fun onDestroy() {
		unregisterReceiver()
		super.onDestroy()
	}

	private fun registerReceiver() {
		val filter = IntentFilter().apply {
			addAction(Intent.ACTION_TIME_TICK)
			addAction(Intent.ACTION_TIME_CHANGED)
			addAction(Intent.ACTION_TIMEZONE_CHANGED)
		}

		try {
			registerReceiver(timeChangeReceiver, filter)
		} catch (_: IllegalArgumentException) {
			// Receiver may already be registered during a hot restart.
		}
	}

	private fun unregisterReceiver() {
		try {
			unregisterReceiver(timeChangeReceiver)
		} catch (_: IllegalArgumentException) {
			// Receiver was not registered.
		}
	}

	private fun emitCurrentTime() {
		mainHandler.post {
			eventSink?.success(System.currentTimeMillis())
		}
	}
}
