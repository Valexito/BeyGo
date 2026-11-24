import { before, after, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import { createEnv, seed, asAnon, asUser, asAdmin, UID } from './helpers.mjs';

let env;
const IMG = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0, 1, 2, 3]); // cabecera JPEG de juguete
const jpeg = { contentType: 'image/jpeg' };

// Archivos preexistentes (subidos con reglas desactivadas).
async function seedFiles() {
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const st = ctx.storage();
    await uploadBytes(ref(st, 'provider_requests/req1/dpi_front.jpg'), IMG, jpeg);
    await uploadBytes(ref(st, `users/${UID.userA}/profile.jpg`), IMG, jpeg);
    await uploadBytes(ref(st, `support_reports/${UID.userA}/rep1/shot.jpg`), IMG, jpeg);
    await uploadBytes(ref(st, 'parkings/park1/photos/p1.jpg'), IMG, jpeg);
  });
}

before(async () => { env = await createEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => { await seed(env); await seedFiles(); });

const st = (ctx) => ctx.storage();

describe('[C07] Storage: documentos de solicitud de proveedor (DPI, patente)', () => {
  it('otro usuario NO puede leer el DPI de una solicitud ajena', async () => {
    await assertFails(getBytes(ref(st(asUser(env, UID.userB)), 'provider_requests/req1/dpi_front.jpg')));
  });
  it('sin sesion NO se puede leer', async () => {
    await assertFails(getBytes(ref(st(asAnon(env)), 'provider_requests/req1/dpi_front.jpg')));
  });
  it('el solicitante SI puede leer su documento', async () => {
    await assertSucceeds(getBytes(ref(st(asUser(env, UID.userA)), 'provider_requests/req1/dpi_front.jpg')));
  });
  it('el admin SI puede leer el documento', async () => {
    await assertSucceeds(getBytes(ref(st(asAdmin(env)), 'provider_requests/req1/dpi_front.jpg')));
  });
  it('otro usuario NO puede sobrescribir ni borrar el documento', async () => {
    const s = st(asUser(env, UID.userB));
    await assertFails(uploadBytes(ref(s, 'provider_requests/req1/dpi_front.jpg'), IMG, jpeg));
    await assertFails(deleteObject(ref(s, 'provider_requests/req1/dpi_front.jpg')));
  });
  it('el solicitante SI puede subir nuevos documentos a su solicitud', async () => {
    await assertSucceeds(uploadBytes(ref(st(asUser(env, UID.userA)), 'provider_requests/req1/patent.jpg'), IMG, jpeg));
  });
  it('flujo real: se suben fotos ANTES de crear el documento de la solicitud', async () => {
    await assertSucceeds(uploadBytes(ref(st(asUser(env, UID.userB)), 'provider_requests/reqNueva/dpi_front.jpg'), IMG, jpeg));
  });
  it('NO se aceptan archivos que no sean imagen', async () => {
    await assertFails(uploadBytes(ref(st(asUser(env, UID.userA)), 'provider_requests/req1/virus.pdf'), IMG, { contentType: 'application/pdf' }));
  });
  it('NO se aceptan imagenes de 10 MB o mas', async () => {
    const big = new Uint8Array(10 * 1024 * 1024);
    await assertFails(uploadBytes(ref(st(asUser(env, UID.userA)), 'provider_requests/req1/grande.jpg'), big, jpeg));
  });
});

describe('[C07] Storage: fotos de perfil y reportes', () => {
  it('otro usuario NO puede leer la foto de perfil ajena', async () => {
    await assertFails(getBytes(ref(st(asUser(env, UID.userB)), `users/${UID.userA}/profile.jpg`)));
  });
  it('el dueño SI puede leer y reemplazar su foto', async () => {
    const s = st(asUser(env, UID.userA));
    await assertSucceeds(getBytes(ref(s, `users/${UID.userA}/profile.jpg`)));
    await assertSucceeds(uploadBytes(ref(s, `users/${UID.userA}/profile.jpg`), IMG, jpeg));
  });
  it('otro usuario NO puede subir a la carpeta de otro', async () => {
    await assertFails(uploadBytes(ref(st(asUser(env, UID.userB)), `users/${UID.userA}/x.jpg`), IMG, jpeg));
  });
  it('capturas de reportes: otro usuario NO las lee', async () => {
    await assertFails(getBytes(ref(st(asUser(env, UID.userB)), `support_reports/${UID.userA}/rep1/shot.jpg`)));
  });
});

describe('[C07] Storage: fotos de parqueos', () => {
  it('lectura publica de fotos del catalogo (por diseño)', async () => {
    await assertSucceeds(getBytes(ref(st(asAnon(env)), 'parkings/park1/photos/p1.jpg')));
  });
  it('un usuario cualquiera NO puede subir ni reemplazar fotos de un parqueo ajeno', async () => {
    await assertFails(uploadBytes(ref(st(asUser(env, UID.userA)), 'parkings/park1/photos/p1.jpg'), IMG, jpeg));
  });
  it('otro proveedor NO puede subir fotos a un parqueo ajeno', async () => {
    await assertFails(uploadBytes(ref(st(asUser(env, UID.prov2)), 'parkings/park1/photos/x.jpg'), IMG, jpeg));
  });
  it('el proveedor dueño SI puede subir fotos', async () => {
    await assertSucceeds(uploadBytes(ref(st(asUser(env, UID.prov1)), 'parkings/park1/photos/nueva.jpg'), IMG, jpeg));
  });
  it('el proveedor NO puede subir archivos que no sean imagen', async () => {
    await assertFails(uploadBytes(ref(st(asUser(env, UID.prov1)), 'parkings/park1/photos/a.pdf'), IMG, { contentType: 'application/pdf' }));
  });
  it('solo el admin puede borrar fotos del parqueo', async () => {
    await assertFails(deleteObject(ref(st(asUser(env, UID.prov1)), 'parkings/park1/photos/p1.jpg')));
    await assertSucceeds(deleteObject(ref(st(asAdmin(env)), 'parkings/park1/photos/p1.jpg')));
  });
});

describe('Denegacion por defecto (Storage)', () => {
  it('ruta no declarada: lectura y escritura denegadas', async () => {
    const s = st(asUser(env, UID.userA));
    await assertFails(uploadBytes(ref(s, 'otros/archivo.jpg'), IMG, jpeg));
    await assertFails(getBytes(ref(s, 'otros/archivo.jpg')));
  });
});
