@file:OptIn(com.google.firebase.ai.type.PublicPreviewAPI::class)
package com.example.appforge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.Firebase
import com.google.firebase.ai.GenerativeModel
import com.google.firebase.ai.ai
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.ondevice.FirebaseAIOnDevice
import com.google.firebase.ai.ondevice.OnDeviceModelStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collect

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.appforge/hybrid_inference"
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkModelStatus" -> {
                    checkModelStatus(result)
                }
                "downloadModel" -> {
                    downloadModel(result)
                }
                "generateHybridContent" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val modelName = call.argument<String>("modelName") ?: "gemini-1.5-flash"
                    generateHybridContent(modelName, prompt, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkModelStatus(result: MethodChannel.Result) {
        scope.launch {
            try {
                val status = FirebaseAIOnDevice.checkStatus()
                result.success(status.toString())
            } catch (e: Exception) {
                result.error("CHECK_FAILED", e.message, null)
            }
        }
    }

    private fun downloadModel(result: MethodChannel.Result) {
        scope.launch {
            try {
                FirebaseAIOnDevice.download().collect { downloadProgress ->
                    // For simplicity, just returning success when done
                }
                result.success("DOWNLOAD_COMPLETE")
            } catch (e: Exception) {
                result.error("DOWNLOAD_FAILED", e.message, null)
            }
        }
    }

    private fun generateHybridContent(modelName: String, prompt: String, result: MethodChannel.Result) {
        val model = Firebase.ai.generativeModel(
            modelName = modelName,
            onDeviceConfig = OnDeviceConfig(
                mode = InferenceMode.PREFER_ON_DEVICE
            )
        )

        scope.launch {
            try {
                val response = model.generateContent(prompt)
                val source = response.inferenceSource.toString()
                val responseText = response.text ?: ""
                result.success(mapOf(
                    "text" to responseText,
                    "source" to source
                ))
            } catch (e: Exception) {
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }
}
