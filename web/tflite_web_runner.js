(function () {
  const inputSize = 320;
  let modelPromise = null;

  function ensureTfLite() {
    if (!globalThis.tf || !globalThis.tflite) {
      throw new Error('TensorFlow.js TFLite no esta cargado en el navegador.');
    }

    if (typeof globalThis.tflite.setWasmPath === 'function') {
      globalThis.tflite.setWasmPath(
        'https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite@0.0.1-alpha.10/wasm/'
      );
    }
  }

  function toUint8Array(value) {
    if (value instanceof Uint8Array) {
      return value;
    }

    if (value instanceof ArrayBuffer) {
      return new Uint8Array(value);
    }

    if (ArrayBuffer.isView(value)) {
      return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    }

    return new Uint8Array(Array.from(value));
  }

  async function bytesToImage(bytes) {
    const blob = new Blob([bytes], { type: 'image/jpeg' });

    if ('createImageBitmap' in globalThis) {
      return createImageBitmap(blob);
    }

    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error('No se pudo decodificar la imagen seleccionada.'));
      image.src = URL.createObjectURL(blob);
    });
  }

  function imageToInputTensor(image) {
    const canvas = document.createElement('canvas');
    canvas.width = inputSize;
    canvas.height = inputSize;

    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0, inputSize, inputSize);

    const { data } = context.getImageData(0, 0, inputSize, inputSize);
    const input = new Float32Array(inputSize * inputSize * 3);

    for (let source = 0, target = 0; source < data.length; source += 4) {
      input[target++] = data[source] / 255;
      input[target++] = data[source + 1] / 255;
      input[target++] = data[source + 2] / 255;
    }

    return tf.tensor(input, [1, inputSize, inputSize, 3], 'float32');
  }

  function tensorListFromPrediction(prediction) {
    if (Array.isArray(prediction)) {
      return prediction;
    }

    if (prediction && typeof prediction === 'object') {
      return Object.values(prediction);
    }

    return [prediction];
  }

  function isIntegerish(value) {
    return Math.abs(value - Math.round(value)) < 0.001;
  }

  async function readOutputTensors(prediction) {
    const tensors = tensorListFromPrediction(prediction);
    const outputs = [];

    for (const tensor of tensors) {
      try {
        outputs.push({
          shape: tensor.shape,
          values: Array.from(await tensor.data()),
        });
      } finally {
        if (tensor && typeof tensor.dispose === 'function') {
          tensor.dispose();
        }
      }
    }

    return outputs;
  }

  function findDetectionOutputs(outputs) {
    const boxes = outputs.find((output) => {
      const shape = output.shape;
      return shape.length === 3 && shape[0] === 1 && shape[2] === 4;
    });
    const vectors = outputs.filter((output) => {
      const shape = output.shape;
      return shape.length === 2 && shape[0] === 1 && output.values.length > 1;
    });
    const numDetections = outputs.find((output) => output.values.length === 1);

    if (!boxes || vectors.length < 2) {
      throw new Error('El TFLite web no devolvio las salidas SSD esperadas.');
    }

    const classes = vectors.find((output) =>
      output.values.every((value) => value >= 0 && isIntegerish(value))
    );
    const scores = vectors.find((output) => output !== classes);

    if (!classes || !scores) {
      throw new Error('No se pudieron identificar clases y puntajes del TFLite web.');
    }

    return { boxes, classes, scores, numDetections };
  }

  function buildDetections(outputs, labels, confidenceThreshold) {
    const { boxes, classes, scores, numDetections } = findDetectionOutputs(outputs);
    const count = Math.min(
      boxes.shape[1],
      scores.values.length,
      classes.values.length,
      Math.max(0, Math.round(numDetections ? numDetections.values[0] : scores.values.length))
    );
    const safeLabels = Array.from(labels || []);
    const detections = [];

    for (let index = 0; index < count; index += 1) {
      const confidence = scores.values[index];
      if (confidence < confidenceThreshold) {
        continue;
      }

      const classIndex = Math.round(classes.values[index]);
      const label = safeLabels[classIndex] || `clase ${classIndex}`;
      const boxOffset = index * 4;

      detections.push({
        label,
        confidence,
        yMin: boxes.values[boxOffset],
        xMin: boxes.values[boxOffset + 1],
        yMax: boxes.values[boxOffset + 2],
        xMax: boxes.values[boxOffset + 3],
      });
    }

    detections.sort((a, b) => b.confidence - a.confidence);
    return detections;
  }

  globalThis.CacaoScanTflite = {
    async load(modelBytes) {
      ensureTfLite();

      if (!modelPromise) {
        const bytes = toUint8Array(modelBytes);
        const modelBuffer = bytes.buffer.slice(
          bytes.byteOffset,
          bytes.byteOffset + bytes.byteLength
        );
        modelPromise = tflite.loadTFLiteModel(modelBuffer, { numThreads: 1 });
      }

      await modelPromise;
    },

    async analyze(modelBytes, imageBytes, labels, confidenceThreshold) {
      ensureTfLite();
      await this.load(modelBytes);

      const model = await modelPromise;
      const image = await bytesToImage(toUint8Array(imageBytes));
      const inputTensor = imageToInputTensor(image);

      try {
        const prediction = model.predict(inputTensor);
        const outputs = await readOutputTensors(prediction);
        return buildDetections(outputs, labels, confidenceThreshold);
      } finally {
        inputTensor.dispose();
      }
    },
  };
})();
