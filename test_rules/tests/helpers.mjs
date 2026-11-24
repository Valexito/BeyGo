import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, Timestamp } from 'firebase/firestore';

export const PROJECT_ID = 'demo-beygo-rules';

// Identidades de prueba (ninguna corresponde a usuarios reales).
export const UID = {
  userA: 'userA',
  userB: 'userB',
  prov1: 'prov1',
  prov2: 'prov2',
  admin: 'adminUser',
};

export async function createEnv() {
  const env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8') },
  });
  return env;
}

// Datos semilla (se escriben con las reglas desactivadas).
export async function seed(env) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = Timestamp.now();
    await setDoc(doc(db, 'users', UID.userA), { uid: UID.userA, email: 'a@test.local', name: 'Usuario A', role: 'user' });
    await setDoc(doc(db, 'users', UID.userB), { uid: UID.userB, email: 'b@test.local', name: 'Usuario B', role: 'user' });
    await setDoc(doc(db, 'users', UID.prov1), { uid: UID.prov1, email: 'p1@test.local', name: 'Proveedor 1', role: 'provider', providerStatus: 'approved' });
    await setDoc(doc(db, 'users', UID.prov2), { uid: UID.prov2, email: 'p2@test.local', name: 'Proveedor 2', role: 'provider', providerStatus: 'approved' });
    await setDoc(doc(db, 'parkings', 'park1'), { ownerID: UID.prov1, name: 'Parqueo de prueba' });
    await setDoc(doc(db, 'parkings', 'park1', 'spaces', '1'), { status: 'free', number: 1 });
    await setDoc(doc(db, 'reservations', 'res1'), {
      userId: UID.userA, ownerId: UID.prov1, parkingId: 'park1', parkingName: 'Parqueo de prueba',
      spaceNumber: 1, state: 'pending', providerApprovalStatus: 'pending', reservedAt: now,
    });
    await setDoc(doc(db, 'reservations', 'res1', 'messages', 'm1'), {
      reservationId: 'res1', senderId: UID.userA, senderRole: 'user', text: 'hola', createdAt: now,
    });
    await setDoc(doc(db, 'provider_requests', 'req1'), { uid: UID.userA, status: 'pending' });
    await setDoc(doc(db, 'support_reports', 'rep1'), { userId: UID.userA, reportId: 'rep1', subject: 's', message: 'm' });
    await setDoc(doc(db, 'favorites', 'favA'), { userId: UID.userA, parkingId: 'park1' });
    await setDoc(doc(db, 'account_deletion_requests', 'del1'), { email: 'x@test.local', status: 'pending' });
  });
}

// Contextos por rol.
export const asAnon = (env) => env.unauthenticatedContext();
export const asUser = (env, uid) => env.authenticatedContext(uid);
export const asAdmin = (env) => env.authenticatedContext(UID.admin, { admin: true });
