import * as tf from '@tensorflow/tfjs-node';
import path from 'path';
import { Elysia, t } from 'elysia';
import crypto from 'crypto';
import { Firestore } from '@google-cloud/firestore';
import { cors } from '@elysiajs/cors';

const firestore = new Firestore({
  keyFilename: path.resolve(__dirname, '../serviceaccountkey.json'),
  databaseId: '(default)',
});

async function savePrediction(data: {
  id: `${string}-${string}-${string}-${string}-${string}`;
  result: string;
  suggestion: string;
  createdAt: string;
}) {
  const docRef = firestore.collection('predictions').doc(data.id);
  await docRef.set(data);
}

async function loadModel() {
  try {
    const pathToModel = path.resolve(__dirname, '../model/model.json');
    const model = await tf.loadGraphModel(`file://${pathToModel}`);
    return model;
  } catch (error) {
    throw new Error('Error loading the model');
  }
}

async function predictImage(
  model: tf.GraphModel,
  image: File
): Promise<{
  confidence: number;
  label: string;
}> {
  const buffer = await image.arrayBuffer();
  const uint8Array = new Uint8Array(buffer);
  const tensor = tf.node
    .decodePng(uint8Array)
    .resizeNearestNeighbor([224, 224])
    .toFloat()
    .expandDims();

  const prediction = model.predict(tensor) as tf.Tensor;
  const score = await prediction.data();
  const confidence = Math.max(...score) * 100;
  const label = confidence > 50 ? 'Cancer' : 'Non-cancer';

  return { confidence, label };
}

const app = new Elysia()
  .use(cors({ origin: '*' }))
  .decorate('model', await loadModel())
  .post(
    '/predict',
    async ({ set, body: { image }, model }) => {
      set.headers['content-type'] = 'application/json';
      set.headers['accept'] = 'multipart/form-data';

      if (image.size > 1024 * 1024) {
        set.status = 413;
        return {
          status: 'fail',
          message:
            'Payload content length greater than maximum allowed: 1000000',
        };
      }

      let result = '';
      try {
        const { label } = await predictImage(model, image);
        result = label;
      } catch (error) {
        set.status = 400;
        return {
          status: 'fail',
          message: 'Terjadi kesalahan dalam melakukan prediksi',
        };
      }

      const data = {
        id: crypto.randomUUID(),
        result,
        suggestion:
          result === 'Cancer'
            ? 'Segera periksa ke dokter!'
            : 'Penyakit kanker tidak terdeteksi.',
        createdAt: new Date().toISOString(),
      };

      await savePrediction(data);

      set.status = 201;
      return {
        status: 'success',
        message: 'Model is predicted successfully',
        data,
      };
    },
    {
      body: t.Object({
        image: t.File(),
      }),
    }
  )
  .get('/predict/histories', async ({ set }) => {
    set.headers['content-type'] = 'application/json';

    const snapshot = await firestore.collection('predictions').get();
    const data = snapshot.docs.map((doc) => doc.data());

    return {
      status: 'success',
      data,
    };
  })
  .listen(8080, () => console.log('Server is running on port 8080'));
