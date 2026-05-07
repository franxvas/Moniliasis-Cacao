# tflite_flutter exposes GPU delegate APIs, but this app runs the offline model
# with the default CPU interpreter. Suppress optional GPU delegate references
# so R8 can minify release builds without requiring GPU-only classes.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
