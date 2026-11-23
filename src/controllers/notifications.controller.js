import { createHash } from 'node:crypto';
import { database } from '../config/firebase.js';

export const registrarToken = async (req, res) => {
  try {
    const { token, platform } = req.body;

    if (typeof token !== 'string' || token.trim().length < 20) {
      return res.status(400).json({
        mensaje: 'El token FCM no es válido.',
      });
    }

    if (token.length > 4096) {
      return res.status(400).json({
        mensaje: 'El token FCM excede la longitud permitida.',
      });
    }

    const plataformasPermitidas = ['android', 'ios', 'web'];

    if (!plataformasPermitidas.includes(platform)) {
      return res.status(400).json({
        mensaje: 'La plataforma indicada no es válida.',
      });
    }

    const uid = req.usuario.uid;

    // El hash permite utilizar una clave segura en Realtime Database.
    const tokenId = createHash('sha256')
      .update(token)
      .digest('hex');

    await database
      .ref(`users/${uid}/fcm_tokens/${tokenId}`)
      .set({
        token,
        platform,
        updated_at: new Date().toISOString(),
      });

    return res.status(200).json({
      mensaje: 'Token FCM registrado correctamente.',
    });
  } catch (error) {
    console.error('Error registrando token FCM:', error.message);

    return res.status(500).json({
      mensaje: 'No se pudo registrar el token de notificaciones.',
    });
  }
};
