import { randomInt } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getDatabase } from "firebase-admin/database";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";

if (getApps().length === 0) {
  initializeApp();
}

const auth = getAuth();
const database = getDatabase();

async function requireAdministrator(uid: string | undefined): Promise<string> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const role = (await database.ref(`users/${uid}/role`).get()).val();
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Se requiere una cuenta administradora.");
  }
  return uid;
}

function requiredString(
  value: unknown,
  field: string,
  maximumLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `El campo ${field} es obligatorio.`);
  }
  const result = value.trim();
  if (!result || result.length > maximumLength) {
    throw new HttpsError("invalid-argument", `El campo ${field} no es válido.`);
  }
  return result;
}

function validateEmail(value: unknown): string {
  const email = requiredString(value, "correo", 254);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "El correo no tiene un formato válido.");
  }
  return email;
}

async function reserveCardNumber(uid: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const suffix = randomInt(0, 1_000_000_000_000).toString().padStart(12, "0");
    const cardNumber = `9999${suffix}`;
    const reservation = await database
      .ref(`cardNumbers/${cardNumber}`)
      .transaction(
        (currentValue) => currentValue === null ? uid : undefined,
        undefined,
        false,
      );
    if (reservation.committed) {
      return cardNumber;
    }
  }
  throw new HttpsError("resource-exhausted", "No se pudo generar un número de tarjeta.");
}

export const adminCreateUser = onCall(async (request) => {
  await requireAdministrator(request.auth?.uid);

  const email = validateEmail(request.data?.email);
  const displayName = requiredString(request.data?.displayName, "nombre", 100);
  const password = request.data?.password;
  const authorized = request.data?.authorized;
  if (typeof password !== "string" || password.length < 6 || password.length > 128) {
    throw new HttpsError("invalid-argument", "La contraseña debe tener entre 6 y 128 caracteres.");
  }
  if (typeof authorized !== "boolean") {
    throw new HttpsError("invalid-argument", "El estado de autorización no es válido.");
  }

  let uid: string | undefined;
  let cardNumber: string | undefined;
  try {
    const user = await auth.createUser({
      email,
      password,
      displayName,
      emailVerified: false,
    });
    uid = user.uid;
    cardNumber = await reserveCardNumber(uid);

    await database.ref().update({
      [`users/${uid}`]: {
        nombre: displayName,
        email,
        foto_url: "",
        provider: "password",
        role: "user",
        autorizado: authorized,
        plan_suscripcion: "ninguno",
        dispositivos_vinculados: {},
        card_number: cardNumber,
      },
    });

    return { uid, cardNumber };
  } catch (error) {
    if (uid) {
      try {
        const updates: Record<string, null> = {
          [`users/${uid}`]: null,
        };
        if (cardNumber) {
          updates[`cardNumbers/${cardNumber}`] = null;
        }
        await database.ref().update(updates);
      } catch (cleanupError) {
        logger.error("Could not remove partially created user data", cleanupError);
      }
      try {
        await auth.deleteUser(uid);
      } catch (cleanupError) {
        logger.error("Could not remove partially created auth user", cleanupError);
      }
    }

    if (error instanceof HttpsError) {
      throw error;
    }
    if (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      error.code === "auth/email-already-exists"
    ) {
      throw new HttpsError("already-exists", "Ya existe una cuenta con ese correo.");
    }
    if (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error.code === "auth/invalid-email" || error.code === "auth/invalid-password")
    ) {
      throw new HttpsError("invalid-argument", "El correo o la contraseña no son válidos.");
    }
    logger.error("Could not create user", error);
    throw new HttpsError("internal", "No se pudo crear el usuario.");
  }
});

export const adminUpdateUser = onCall(async (request) => {
  const administratorUid = await requireAdministrator(request.auth?.uid);
  const uid = requiredString(request.data?.uid, "usuario", 128);
  if (uid === administratorUid) {
    throw new HttpsError("failed-precondition", "No puedes modificar tu propia cuenta desde aquí.");
  }

  const displayName = requiredString(request.data?.displayName, "nombre", 100);
  const email = validateEmail(request.data?.email);
  const authorized = request.data?.authorized;
  if (typeof authorized !== "boolean") {
    throw new HttpsError("invalid-argument", "El estado de autorización no es válido.");
  }

  const profileRef = database.ref(`users/${uid}`);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.val() as Record<string, unknown> | null;
  if (!profile || profile.role !== "user") {
    throw new HttpsError("not-found", "No se encontró el usuario normal.");
  }

  const emailChanged = profile.email !== email;
  try {
    await auth.updateUser(uid, {
      displayName,
      email,
      ...(emailChanged ? { emailVerified: false } : {}),
    });
    await profileRef.update({
      nombre: displayName,
      email,
      autorizado,
    });
  } catch (error) {
    logger.error("Could not update user", { uid, error });
    throw new HttpsError("internal", "No se pudo actualizar el usuario.");
  }

  return { uid };
});

export const adminDeleteUser = onCall(async (request) => {
  const administratorUid = await requireAdministrator(request.auth?.uid);
  const uid = requiredString(request.data?.uid, "usuario", 128);
  if (uid === administratorUid) {
    throw new HttpsError("failed-precondition", "No puedes eliminar tu propia cuenta desde aquí.");
  }

  const profileRef = database.ref(`users/${uid}`);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.val() as Record<string, unknown> | null;
  if (!profile || profile.role !== "user") {
    throw new HttpsError("not-found", "No se encontró el usuario normal.");
  }

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (
      typeof error !== "object" ||
      error === null ||
      !("code" in error) ||
      error.code !== "auth/user-not-found"
    ) {
      logger.error("Could not delete auth user", { uid, error });
      throw new HttpsError("internal", "No se pudo eliminar la cuenta.");
    }
  }

  const updates: Record<string, null> = {
    [`users/${uid}`]: null,
  };
  if (typeof profile.card_number === "string") {
    updates[`cardNumbers/${profile.card_number}`] = null;
  }

  try {
    await database.ref().update(updates);
  } catch (error) {
    logger.error("Auth user deleted but database cleanup failed", { uid, error });
    throw new HttpsError("internal", "La cuenta se eliminó, pero no se pudo limpiar su perfil.");
  }

  return { uid };
});
