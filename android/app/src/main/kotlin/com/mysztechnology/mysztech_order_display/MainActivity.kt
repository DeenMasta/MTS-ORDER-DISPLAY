package com.mysztechnology.mysztech_order_display

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val kitchenAlertsChannel =
        "com.mysztechnology.mysztech_order_display/kitchen_alerts"
    private val alertHandler = Handler(Looper.getMainLooper())
    private var alertGeneration = 0
    private var activeToneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kitchenAlertsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playNewOrder" -> {
                        playTones(
                            listOf(
                                ToneStep(ToneGenerator.TONE_PROP_BEEP, 130),
                                ToneStep(ToneGenerator.TONE_PROP_BEEP2, 220),
                            ),
                        )
                        result.success(null)
                    }
                    "playUrgentOrder" -> {
                        playTones(
                            listOf(
                                ToneStep(ToneGenerator.TONE_PROP_NACK, 130),
                                ToneStep(ToneGenerator.TONE_PROP_NACK, 130),
                                ToneStep(ToneGenerator.TONE_PROP_PROMPT, 280),
                            ),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playTones(tones: List<ToneStep>) {
        alertGeneration += 1
        val generation = alertGeneration
        activeToneGenerator?.release()
        val generator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        activeToneGenerator = generator
        var delayMillis = 0L

        for (tone in tones) {
            alertHandler.postDelayed(
                {
                    if (generation == alertGeneration) {
                        generator.startTone(tone.type, tone.durationMillis)
                    }
                },
                delayMillis,
            )
            delayMillis += tone.durationMillis + 55L
        }
        alertHandler.postDelayed(
            {
                if (generation == alertGeneration) {
                    generator.release()
                    if (activeToneGenerator === generator) {
                        activeToneGenerator = null
                    }
                }
            },
            delayMillis,
        )
    }

    override fun onDestroy() {
        alertGeneration += 1
        activeToneGenerator?.release()
        activeToneGenerator = null
        super.onDestroy()
    }

    private data class ToneStep(val type: Int, val durationMillis: Int)
}
