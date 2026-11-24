"use strict";

// Pruebas de la depuración automática de reservaciones contra el emulador de
// Firestore (no toca producción). Ejecutar desde test_rules:
//   npm run test:depuracion        (o test:depuracion:evidencia para guardar el registro)

const { test, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { purgeExpiredReservations } = require("../lib/retention");

const NOW = new Date("2026-10-24T12:00:00Z"); // plazo de 24 meses => corte 2024-10-24T12:00Z
let db;

const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
const exists = async (id) => (await db.collection("reservations").doc(id).get()).exists;

async function seed(id, state, reservedAtIso, withSubcollections = false) {
    const data = { userId: "u1", ownerId: "o1" };
    if (state !== undefined) data.state = state;
    if (reservedAtIso) data.reservedAt = ts(reservedAtIso);
    const ref = db.collection("reservations").doc(id);
    await ref.set(data);
    if (withSubcollections) {
        await ref.collection("messages").doc("m1").set({ text: "hola" });
        await ref.collection("chat_blocks").doc("u1").set({ blockedUid: "o1" });
    }
    return ref;
}

before(() => {
    assert.ok(
        process.env.FIRESTORE_EMULATOR_HOST,
        "Falta FIRESTORE_EMULATOR_HOST: ejecuta con firebase emulators:exec (npm run test:depuracion)."
    );
    if (!admin.apps.length) admin.initializeApp({ projectId: "demo-beygo-purge" });
    db = admin.firestore();
});

beforeEach(async () => {
    for (const c of ["reservations", "users", "parkings"]) {
        await db.recursiveDelete(db.collection(c));
    }
});

test("elimina las reservaciones terminadas vencidas y sus subcolecciones", async () => {
    const refs = [];
    refs.push(await seed("r-completed", "completed", "2024-01-10T10:00:00Z", true));
    refs.push(await seed("r-cancelled", "cancelled", "2024-02-10T10:00:00Z", true));
    refs.push(await seed("r-manual", "manual_completed", "2024-03-10T10:00:00Z", true));
    const res = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal(res.matched, 3);
    assert.equal(res.deleted, 3);
    assert.equal(res.failed, 0);
    for (const ref of refs) {
        assert.equal((await ref.get()).exists, false, `${ref.id} debía eliminarse`);
        assert.equal((await ref.collection("messages").get()).size, 0, `${ref.id}/messages`);
        assert.equal((await ref.collection("chat_blocks").get()).size, 0, `${ref.id}/chat_blocks`);
    }
});

test("conserva las reservaciones vencidas que no están terminadas", async () => {
    await seed("r-pending", "pending", "2024-01-10T10:00:00Z");
    await seed("r-active", "active", "2024-01-11T10:00:00Z");
    await seed("r-cancel-req", "cancellation_requested", "2024-01-12T10:00:00Z");
    const res = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal(res.matched, 0);
    assert.equal(res.deleted, 0);
    for (const id of ["r-pending", "r-active", "r-cancel-req"]) {
        assert.equal(await exists(id), true, `${id} debía conservarse`);
    }
});

test("respeta el límite de 24 meses: conserva lo reciente y elimina lo anterior al corte", async () => {
    await seed("r-just-inside", "completed", "2024-10-25T00:00:00Z"); // 1 día más reciente que el corte
    await seed("r-just-outside", "completed", "2024-10-23T00:00:00Z"); // 1 día anterior al corte
    await seed("r-recent", "completed", "2026-09-01T00:00:00Z");
    const res = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal(res.deleted, 1);
    assert.equal(await exists("r-just-inside"), true);
    assert.equal(await exists("r-recent"), true);
    assert.equal(await exists("r-just-outside"), false);
});

test("conserva documentos sin reservedAt o sin estado", async () => {
    await seed("r-no-date", "completed", undefined);
    await seed("r-no-state", undefined, "2024-01-10T10:00:00Z");
    const res = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal(res.deleted, 0);
    assert.equal(await exists("r-no-date"), true);
    assert.equal(await exists("r-no-state"), true);
});

test("en modo de simulación cuenta las coincidencias pero no borra nada", async () => {
    await seed("r-old-1", "completed", "2024-01-10T10:00:00Z", true);
    await seed("r-old-2", "cancelled", "2024-02-10T10:00:00Z");
    const res = await purgeExpiredReservations(db, { dryRun: true, now: NOW });
    assert.equal(res.matched, 2);
    assert.equal(res.deleted, 0);
    assert.equal(await exists("r-old-1"), true);
    assert.equal(await exists("r-old-2"), true);
    assert.equal(
        (await db.collection("reservations").doc("r-old-1").collection("messages").get()).size,
        1
    );
});

test("recorre varias páginas sin saltarse documentos (páginas de 3)", async () => {
    // 12 reservaciones vencidas, intercaladas: terminadas (pares) y activas (impares)
    for (let i = 0; i < 12; i += 1) {
        const day = String(i + 1).padStart(2, "0");
        await seed(`r-${day}`, i % 2 === 0 ? "completed" : "active", `2024-01-${day}T10:00:00Z`);
    }
    const res = await purgeExpiredReservations(db, { dryRun: false, now: NOW, pageSize: 3 });
    assert.equal(res.scanned, 12);
    assert.equal(res.matched, 6);
    assert.equal(res.deleted, 6);
    for (let i = 0; i < 12; i += 1) {
        const day = String(i + 1).padStart(2, "0");
        assert.equal(await exists(`r-${day}`), i % 2 !== 0, `r-${day}`);
    }
});

test("una segunda ejecución no elimina nada más", async () => {
    await seed("r-old", "completed", "2024-01-10T10:00:00Z");
    const first = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    const second = await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal(first.deleted, 1);
    assert.equal(second.scanned, 0);
    assert.equal(second.deleted, 0);
});

test("no modifica otras colecciones", async () => {
    await db.collection("users").doc("u1").set({ email: "a@b.com" });
    await db.collection("parkings").doc("p1").set({ name: "Parqueo de prueba" });
    await seed("r-old", "completed", "2024-01-10T10:00:00Z");
    await purgeExpiredReservations(db, { dryRun: false, now: NOW });
    assert.equal((await db.collection("users").doc("u1").get()).exists, true);
    assert.equal((await db.collection("parkings").doc("p1").get()).exists, true);
});
