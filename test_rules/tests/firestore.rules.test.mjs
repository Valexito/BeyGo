import { before, after, beforeEach, describe, it } from 'node:test';
import {
  assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, query, where, collection, Timestamp, serverTimestamp,
} from 'firebase/firestore';
import { createEnv, seed, asAnon, asUser, asAdmin, UID } from './helpers.mjs';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => { await seed(env); });

const dbOf = (ctx) => ctx.firestore();

describe('[C05] Roles: un usuario no puede escalar privilegios', () => {
  it('usuario NO puede asignarse role = provider', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(updateDoc(doc(db, 'users', UID.userA), { role: 'provider' }));
  });
  it('usuario NO puede asignarse role = admin', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(updateDoc(doc(db, 'users', UID.userA), { role: 'admin' }));
  });
  it('usuario NO puede marcarse providerStatus = approved', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(updateDoc(doc(db, 'users', UID.userA), { providerStatus: 'approved' }));
  });
  it('usuario NO puede crear su perfil con role = provider', async () => {
    const db = dbOf(asUser(env, 'userC'));
    await assertFails(setDoc(doc(db, 'users', 'userC'), { uid: 'userC', email: 'c@test.local', role: 'provider' }));
  });
  it('usuario SI puede crear su perfil con role = user', async () => {
    const db = dbOf(asUser(env, 'userC'));
    await assertSucceeds(setDoc(doc(db, 'users', 'userC'), { uid: 'userC', email: 'c@test.local', role: 'user' }));
  });
  it('usuario SI puede enviar su solicitud (providerStatus = pending)', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertSucceeds(updateDoc(doc(db, 'users', UID.userA), { providerStatus: 'pending' }));
  });
  it('usuario SI puede editar su nombre y telefono', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertSucceeds(updateDoc(doc(db, 'users', UID.userA), { name: 'Nuevo nombre', phone: '5555-5555', updatedAt: serverTimestamp() }));
  });
  it('proveedor tampoco puede cambiarse a admin', async () => {
    const db = dbOf(asUser(env, UID.prov1));
    await assertFails(updateDoc(doc(db, 'users', UID.prov1), { role: 'admin' }));
  });
  it('admin (claim) SI puede aprobar: role = provider y providerStatus = approved', async () => {
    const db = dbOf(asAdmin(env));
    await assertSucceeds(updateDoc(doc(db, 'users', UID.userA), { role: 'provider', providerStatus: 'approved', updatedAt: serverTimestamp() }));
  });
});

describe('[C06] Aislamiento de datos entre usuarios (Firestore)', () => {
  it('usuario NO puede leer el perfil de otro usuario', async () => {
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.userA)), 'users', UID.userB)));
  });
  it('usuario SI puede leer su propio perfil', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asUser(env, UID.userA)), 'users', UID.userA)));
  });
  it('sin sesion NO se puede leer ningun perfil', async () => {
    await assertFails(getDoc(doc(dbOf(asAnon(env)), 'users', UID.userA)));
  });
  it('usuario NO puede modificar el perfil de otro', async () => {
    await assertFails(updateDoc(doc(dbOf(asUser(env, UID.userB)), 'users', UID.userA), { name: 'hack' }));
  });
  it('usuario NO puede leer vehiculos de otro usuario', async () => {
    await assertFails(getDocs(collection(dbOf(asUser(env, UID.userB)), 'users', UID.userA, 'vehicles')));
  });

  it('reserva: el usuario dueño SI la lee', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asUser(env, UID.userA)), 'reservations', 'res1')));
  });
  it('reserva: el proveedor del parqueo SI la lee', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asUser(env, UID.prov1)), 'reservations', 'res1')));
  });
  it('reserva: otro usuario NO la lee', async () => {
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.userB)), 'reservations', 'res1')));
  });
  it('reserva: otro proveedor NO la lee', async () => {
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.prov2)), 'reservations', 'res1')));
  });
  it('reserva: sin sesion NO se lee', async () => {
    await assertFails(getDoc(doc(dbOf(asAnon(env)), 'reservations', 'res1')));
  });
  it('reserva: otro usuario NO puede cancelarla (update)', async () => {
    await assertFails(updateDoc(doc(dbOf(asUser(env, UID.userB)), 'reservations', 'res1'), { state: 'cancelled' }));
  });
  it('reserva: otro usuario NO puede borrarla', async () => {
    await assertFails(deleteDoc(doc(dbOf(asUser(env, UID.userB)), 'reservations', 'res1')));
  });
  it('reserva: NO se puede crear a nombre de otro usuario', async () => {
    const db = dbOf(asUser(env, UID.userB));
    await assertFails(setDoc(doc(db, 'reservations', 'resX'), {
      userId: UID.userA, ownerId: UID.prov1, parkingId: 'park1', parkingName: 'P', spaceNumber: 1,
      state: 'pending', providerApprovalStatus: 'pending', reservedAt: Timestamp.now(),
    }));
  });
  it('reserva: el usuario SI crea la suya', async () => {
    const db = dbOf(asUser(env, UID.userB));
    await assertSucceeds(setDoc(doc(db, 'reservations', 'resB'), {
      userId: UID.userB, ownerId: UID.prov1, parkingId: 'park1', parkingName: 'P', spaceNumber: 1,
      state: 'pending', providerApprovalStatus: 'pending', reservedAt: Timestamp.now(),
    }));
  });
  it('reserva: el usuario NO puede cambiar campos fuera de su lista (p. ej. el proveedor/dueño)', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(updateDoc(doc(db, 'reservations', 'res1'), { ownerId: UID.userA }));
  });
  it('chat: otro usuario NO lee los mensajes de la reserva', async () => {
    await assertFails(getDocs(collection(dbOf(asUser(env, UID.userB)), 'reservations', 'res1', 'messages')));
  });
  it('chat: el participante SI lee los mensajes', async () => {
    await assertSucceeds(getDocs(collection(dbOf(asUser(env, UID.userA)), 'reservations', 'res1', 'messages')));
  });

  it('favoritos: otro usuario NO lee ni borra el favorito ajeno', async () => {
    const db = dbOf(asUser(env, UID.userB));
    await assertFails(getDoc(doc(db, 'favorites', 'favA')));
    await assertFails(deleteDoc(doc(db, 'favorites', 'favA')));
  });
  it('favoritos: el dueño SI lo lee (consulta por userId) y lo borra', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertSucceeds(getDocs(query(collection(db, 'favorites'), where('userId', '==', UID.userA))));
    await assertSucceeds(deleteDoc(doc(db, 'favorites', 'favA')));
  });

  it('reportes de soporte: otro usuario NO los lee', async () => {
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.userB)), 'support_reports', 'rep1')));
  });
  it('reportes de soporte: el autor SI; el admin SI', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asUser(env, UID.userA)), 'support_reports', 'rep1')));
    await assertSucceeds(getDoc(doc(dbOf(asAdmin(env)), 'support_reports', 'rep1')));
  });
  it('reportes de soporte: el autor NO puede editarlos ni borrarlos', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(updateDoc(doc(db, 'support_reports', 'rep1'), { message: 'cambio' }));
    await assertFails(deleteDoc(doc(db, 'support_reports', 'rep1')));
  });
});

describe('[C04] Solicitudes de proveedor: aprobacion solo por administrador', () => {
  it('usuario SI crea su solicitud', async () => {
    await assertSucceeds(setDoc(doc(dbOf(asUser(env, UID.userB)), 'provider_requests', 'reqB'), { uid: UID.userB, status: 'pending' }));
  });
  it('usuario NO puede crear solicitud a nombre de otro', async () => {
    await assertFails(setDoc(doc(dbOf(asUser(env, UID.userB)), 'provider_requests', 'reqX'), { uid: UID.userA, status: 'pending' }));
  });
  it('otro usuario NO puede leer la solicitud (DPI/patente)', async () => {
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.userB)), 'provider_requests', 'req1')));
  });
  it('el solicitante SI lee su solicitud; el admin SI', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asUser(env, UID.userA)), 'provider_requests', 'req1')));
    await assertSucceeds(getDoc(doc(dbOf(asAdmin(env)), 'provider_requests', 'req1')));
  });
  it('el solicitante NO puede aprobar su propia solicitud', async () => {
    await assertFails(updateDoc(doc(dbOf(asUser(env, UID.userA)), 'provider_requests', 'req1'), { status: 'approved' }));
  });
  it('el admin SI puede aprobar', async () => {
    await assertSucceeds(updateDoc(doc(dbOf(asAdmin(env)), 'provider_requests', 'req1'), { status: 'approved' }));
  });
  it('nadie puede borrar solicitudes (ni el admin)', async () => {
    await assertFails(deleteDoc(doc(dbOf(asUser(env, UID.userA)), 'provider_requests', 'req1')));
    await assertFails(deleteDoc(doc(dbOf(asAdmin(env)), 'provider_requests', 'req1')));
  });
  it('un usuario sin aprobar NO puede crear un parqueo propio', async () => {
    await assertFails(setDoc(doc(dbOf(asUser(env, UID.userA)), 'parkings', 'parkA'), { ownerID: UID.userA, name: 'Falso' }));
  });
  it('un usuario NO puede crear un parqueo a nombre de un proveedor', async () => {
    await assertFails(setDoc(doc(dbOf(asUser(env, UID.userA)), 'parkings', 'parkB'), { ownerID: UID.prov1, name: 'Falso' }));
  });
  it('un proveedor aprobado SI puede crear su parqueo', async () => {
    await assertSucceeds(setDoc(doc(dbOf(asUser(env, UID.prov2)), 'parkings', 'parkP2'), { ownerID: UID.prov2, name: 'Mio' }));
  });
  it('el admin SI crea el parqueo al aprobar', async () => {
    await assertSucceeds(setDoc(doc(dbOf(asAdmin(env)), 'parkings', 'parkNew'), { ownerID: UID.userA, name: 'Nuevo' }));
  });
});

describe('[C05] Datos del parqueo: solo su proveedor o el admin modifican', () => {
  it('lectura publica del catalogo de parqueos (por diseño)', async () => {
    await assertSucceeds(getDoc(doc(dbOf(asAnon(env)), 'parkings', 'park1')));
  });
  it('usuario NO puede modificar un parqueo ajeno', async () => {
    await assertFails(updateDoc(doc(dbOf(asUser(env, UID.userA)), 'parkings', 'park1'), { name: 'hack' }));
  });
  it('otro proveedor NO puede modificar el parqueo', async () => {
    await assertFails(updateDoc(doc(dbOf(asUser(env, UID.prov2)), 'parkings', 'park1'), { name: 'hack' }));
  });
  it('el proveedor dueño SI puede modificarlo', async () => {
    await assertSucceeds(updateDoc(doc(dbOf(asUser(env, UID.prov1)), 'parkings', 'park1'), { name: 'Nuevo nombre' }));
  });
  it('usuario NO puede crear ni borrar espacios del parqueo', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(setDoc(doc(db, 'parkings', 'park1', 'spaces', '2'), { status: 'free', number: 2 }));
    await assertFails(deleteDoc(doc(db, 'parkings', 'park1', 'spaces', '1')));
  });
  it('usuario NO puede leer las entradas manuales (walk_ins) del proveedor', async () => {
    await assertFails(getDocs(collection(dbOf(asUser(env, UID.userA)), 'parkings', 'park1', 'walk_ins')));
  });
});

describe('[C12] Solicitudes de eliminacion de cuenta (formulario web)', () => {
  const valid = () => ({
    email: 'persona@test.local', fullName: 'Persona de Prueba', phone: '', reason: 'no-uso', details: '',
    confirm: true, status: 'pending', source: 'web', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  it('cualquiera puede enviar la solicitud valida (el usuario ya desinstalo la app)', async () => {
    await assertSucceeds(setDoc(doc(dbOf(asAnon(env)), 'account_deletion_requests', 'n1'), valid()));
  });
  it('NO se acepta una solicitud con status distinto de pending', async () => {
    await assertFails(setDoc(doc(dbOf(asAnon(env)), 'account_deletion_requests', 'n2'), { ...valid(), status: 'done' }));
  });
  it('NO se acepta una solicitud con campos extra', async () => {
    await assertFails(setDoc(doc(dbOf(asAnon(env)), 'account_deletion_requests', 'n3'), { ...valid(), isAdmin: true }));
  });
  it('NO se acepta sin confirmacion', async () => {
    await assertFails(setDoc(doc(dbOf(asAnon(env)), 'account_deletion_requests', 'n4'), { ...valid(), confirm: false }));
  });
  it('nadie salvo el admin puede leer las solicitudes', async () => {
    await assertFails(getDoc(doc(dbOf(asAnon(env)), 'account_deletion_requests', 'del1')));
    await assertFails(getDoc(doc(dbOf(asUser(env, UID.userA)), 'account_deletion_requests', 'del1')));
    await assertSucceeds(getDoc(doc(dbOf(asAdmin(env)), 'account_deletion_requests', 'del1')));
  });
});

describe('Denegacion por defecto', () => {
  it('coleccion no declarada: lectura y escritura denegadas', async () => {
    const db = dbOf(asUser(env, UID.userA));
    await assertFails(getDoc(doc(db, 'coleccion_inexistente', 'x')));
    await assertFails(setDoc(doc(db, 'coleccion_inexistente', 'x'), { a: 1 }));
  });
});
