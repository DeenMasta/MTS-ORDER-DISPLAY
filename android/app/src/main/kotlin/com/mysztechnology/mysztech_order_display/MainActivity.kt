package com.mysztechnology.mysztech_order_display

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val kitchenAlertsChannel =
        "com.mysztechnology.mysztech_order_display/kitchen_alerts"
    private val alertHandler = Handler(Looper.getMainLooper())
    private var activeAudioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kitchenAlertsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playTemplateSound" -> {
                        val tone = call.arguments as? String
                        val melody = melodyFor(tone)
                        if (melody == null) {
                            result.error("unknown_template", "Unknown sound template.", null)
                        } else {
                            playBuiltInSound(melody, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun melodyFor(tone: String?): List<ToneStep>? = when (tone) {
        "chime" -> brightChimeMelody
        "bell" -> warmBellMelody
        "pulse" -> quickPulseMelody
        "call" -> kitchenCallMelody
        "alert" -> chimePriorityMelody
        "priority" -> bellPriorityMelody
        "urgentPulse" -> pulsePriorityMelody
        "urgentCall" -> callPriorityMelody
        else -> null
    }

    private fun playBuiltInSound(melody: List<ToneStep>, result: MethodChannel.Result) {
        try {
            stopActiveAlert()
            val samples = buildMelodySamples(melody)
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(samples.size * Short.SIZE_BYTES)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            audioTrack.write(samples, 0, samples.size)
            audioTrack.play()
            activeAudioTrack = audioTrack
            val durationMillis = melody.sumOf { it.durationMillis }.toLong() + 120L
            alertHandler.postDelayed(
                {
                    if (activeAudioTrack === audioTrack) {
                        audioTrack.release()
                        activeAudioTrack = null
                    }
                },
                durationMillis,
            )
            result.success(null)
        } catch (exception: Exception) {
            stopActiveAlert()
            result.error("sound_error", "Unable to play the built-in alert.", null)
        }
    }

    private fun buildMelodySamples(melody: List<ToneStep>): ShortArray {
        val sampleCount = melody.sumOf { sampleRate * it.durationMillis / 1000 }
        val samples = ShortArray(sampleCount)
        var offset = 0
        for (tone in melody) {
            val toneSampleCount = sampleRate * tone.durationMillis / 1000
            val fadeSamples = max(1, min(350, toneSampleCount / 8))
            for (index in 0 until toneSampleCount) {
                if (tone.hertz != 0.0) {
                    val edgeDistance = min(index, toneSampleCount - index - 1)
                    val envelope = min(1.0, edgeDistance.toDouble() / fadeSamples)
                    val soundWave = sin(
                        2.0 * PI * tone.hertz * index / sampleRate,
                    )
                    samples[offset + index] = (
                        soundWave *
                            alertAmplitude *
                            envelope
                        ).roundToInt().toShort()
                }
            }
            offset += toneSampleCount
        }
        return samples
    }

    private fun stopActiveAlert() {
        alertHandler.removeCallbacksAndMessages(null)
        activeAudioTrack?.let { audioTrack ->
            runCatching { audioTrack.stop() }
            audioTrack.release()
        }
        activeAudioTrack = null
    }

    override fun onDestroy() {
        stopActiveAlert()
        super.onDestroy()
    }

    private data class ToneStep(
        val hertz: Double,
        val durationMillis: Int,
    )

    private companion object {
        const val sampleRate = 22050
        const val alertAmplitude = 13000.0

        val brightChimeMelody = listOf(
            ToneStep(783.99, 100),
            ToneStep(0.0, 45),
            ToneStep(987.77, 125),
            ToneStep(0.0, 45),
            ToneStep(1318.51, 190),
        )
        val warmBellMelody = listOf(
            ToneStep(523.25, 165),
            ToneStep(0.0, 70),
            ToneStep(659.25, 190),
            ToneStep(0.0, 60),
            ToneStep(783.99, 240),
        )
        val quickPulseMelody = listOf(
            ToneStep(740.0, 100),
            ToneStep(0.0, 60),
            ToneStep(740.0, 100),
            ToneStep(0.0, 60),
            ToneStep(880.0, 180),
        )
        val kitchenCallMelody = listOf(
            ToneStep(659.25, 150),
            ToneStep(0.0, 65),
            ToneStep(880.0, 220),
        )
        val chimePriorityMelody = listOf(
            ToneStep(783.99, 80),
            ToneStep(0.0, 35),
            ToneStep(987.77, 100),
            ToneStep(0.0, 35),
            ToneStep(1318.51, 130),
            ToneStep(0.0, 55),
            ToneStep(1318.51, 100),
            ToneStep(0.0, 35),
            ToneStep(1567.98, 210),
        )
        val bellPriorityMelody = listOf(
            ToneStep(523.25, 105),
            ToneStep(0.0, 35),
            ToneStep(659.25, 125),
            ToneStep(0.0, 35),
            ToneStep(783.99, 150),
            ToneStep(0.0, 55),
            ToneStep(783.99, 105),
            ToneStep(0.0, 35),
            ToneStep(1046.50, 220),
        )
        val pulsePriorityMelody = listOf(
            ToneStep(740.0, 75),
            ToneStep(0.0, 35),
            ToneStep(740.0, 75),
            ToneStep(0.0, 35),
            ToneStep(880.0, 110),
            ToneStep(0.0, 55),
            ToneStep(740.0, 75),
            ToneStep(0.0, 35),
            ToneStep(740.0, 75),
            ToneStep(0.0, 35),
            ToneStep(1174.66, 200),
        )
        val callPriorityMelody = listOf(
            ToneStep(659.25, 95),
            ToneStep(0.0, 35),
            ToneStep(880.0, 120),
            ToneStep(0.0, 45),
            ToneStep(659.25, 95),
            ToneStep(0.0, 35),
            ToneStep(880.0, 120),
            ToneStep(0.0, 60),
            ToneStep(1046.50, 220),
        )
    }
}
