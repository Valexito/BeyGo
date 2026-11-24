"use strict";

// Pruebas de la integración con Jira (sin red ni Firestore):
//   cd functions && node --test test/jira.test.js

const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
    buildSupportReportTicket, buildProviderRequestTicket, createJiraRequest, ensureJiraTicket, CLAIM_STALE_MS,
} = require("../lib/jira");

// ── Fakes ────────────────────────────────────────────────────────────────
function fakeFetch(responses) {
    const calls = [];
    const fn = async (url, init) => {
        calls.push({ url, init, body: init.body ? JSON.parse(init.body) : null });
        const r = responses.shift();
        return { ok: r.status < 300, status: r.status, json: async () => r.json, text: async () => JSON.stringify(r.json ?? {}) };
    };
    fn.calls = calls;
    return fn;
}

function fakeDoc(initial = {}) {
    let data = JSON.parse(JSON.stringify(initial));
    const merge = (a, b) => {
        for (const [k, v] of Object.entries(b)) {
            if (v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Date)) a[k] = merge(a[k] && typeof a[k] === "object" ? a[k] : {}, v);
            else a[k] = v;
        }
        return a;
    };
    const ref = { set: async (v) => { data = merge(data, v); }, get data() { return data; } };
    const db = {
        runTransaction: async (fn) => fn({
            get: async () => ({ exists: true, data: () => data }),
            set: (_r, v) => { data = merge(data, v); },
        }),
    };
    return { ref, db };
}

const cfg = { baseUrl: "https://ejemplo.atlassian.net/", email: "admin@ejemplo.com", token: "t0k3n", serviceDeskId: "34", requestTypeId: "38" };

// ── Construcción de tickets ─────────────────────────────────────────────
test("reporte de conductor: resumen, descripción y etiquetas", () => {
    const t = buildSupportReportTicket("abc", {
        reportNumber: "REP-1A2B", reportType: "Error en la app", subject: "No carga el mapa",
        userEmail: "u@x.com", userId: "u1", message: "Se queda en blanco", screenshotUrls: ["https://img/1"],
    });
    assert.equal(t.summary, "[REP-1A2B] Error en la app: No carga el mapa");
    assert.match(t.description, /Correo del usuario: u@x\.com/);
    assert.match(t.description, /Se queda en blanco/);
    assert.match(t.description, /1\. https:\/\/img\/1/);
    assert.deepEqual(t.labels, ["beygo", "reporte-conductor", "tipo-error-en-la-app"]);
});

test("reporte de chat: etiqueta propia y datos de la reservación", () => {
    const t = buildSupportReportTicket("abc", { reportNumber: "REP-9", reportType: "chat_message", subject: "Reporte de mensaje de chat", reservationId: "R1", reportedUid: "u9" });
    assert.deepEqual(t.labels, ["beygo", "reporte-chat"]);
    assert.match(t.description, /Reservación: R1/);
});

test("solicitud de proveedor: no copia los enlaces del DPI ni de la patente", () => {
    const t = buildProviderRequestTicket("Xy12ab", {
        requestNumber: "OWN-XY12AB", parkingName: "Parqueo Centro", email: "p@x.com", nit: "123-4",
        lat: 14.83, lng: -91.52, businessHours: { open: "07:00", close: "21:00" }, parkingImages: ["a", "b"],
        documents: { dpiFront: "https://secreto/dpi", dpiBack: "https://secreto/dpi2", patent: "https://secreto/pat" },
    });
    assert.equal(t.summary, "[OWN-XY12AB] Solicitud de proveedor: Parqueo Centro");
    assert.match(t.description, /Horario: 07:00 – 21:00/);
    assert.match(t.description, /maps\.google\.com\/\?q=14\.83,-91\.52/);
    assert.doesNotMatch(t.description, /secreto/);
    assert.deepEqual(t.labels, ["beygo", "solicitud-proveedor", "alta-proveedor"]);
});

test("solicitud de baja de parqueo", () => {
    const t = buildProviderRequestTicket("id1", { requestType: "parking_deletion", parkingName: "Shaddai", reason: "Cierre", activeReservations: 0 });
    assert.equal(t.summary, "[Baja de parqueo] Shaddai");
    assert.match(t.description, /Motivo:\nCierre/);
    assert.deepEqual(t.labels, ["beygo", "solicitud-proveedor", "baja-parqueo"]);
});

test("el resumen se recorta a 240 caracteres", () => {
    const t = buildSupportReportTicket("a", { reportNumber: "REP-1", reportType: "x", subject: "s".repeat(500) });
    assert.equal(t.summary.length, 240);
});

// ── Llamada a Jira ──────────────────────────────────────────────────────
test("crea la solicitud en el service desk y agrega etiquetas", async () => {
    const f = fakeFetch([{ status: 201, json: { issueKey: "POP-7", issueId: "11000" } }, { status: 204 }]);
    const r = await createJiraRequest({ ...cfg, summary: "S", description: "D", labels: ["beygo"], fetchImpl: f });
    assert.equal(r.issueKey, "POP-7");
    assert.equal(r.url, "https://ejemplo.atlassian.net/browse/POP-7");
    assert.equal(f.calls[0].url, "https://ejemplo.atlassian.net/rest/servicedeskapi/request");
    assert.deepEqual(f.calls[0].body, { serviceDeskId: "34", requestTypeId: "38", requestFieldValues: { summary: "S", description: "D" } });
    assert.equal(f.calls[0].init.headers.Authorization, "Basic " + Buffer.from("admin@ejemplo.com:t0k3n").toString("base64"));
    assert.equal(f.calls[1].url, "https://ejemplo.atlassian.net/rest/api/3/issue/POP-7");
    assert.deepEqual(f.calls[1].body, { update: { labels: [{ add: "beygo" }] } });
});

test("un error de Jira se propaga con el código", async () => {
    const f = fakeFetch([{ status: 403, json: { errorMessage: "no es agente" } }]);
    await assert.rejects(createJiraRequest({ ...cfg, summary: "S", description: "D", fetchImpl: f }), /403/);
});

test("si fallan las etiquetas, el ticket se conserva con una advertencia", async () => {
    const f = fakeFetch([{ status: 201, json: { issueKey: "POP-8" } }, { status: 400, json: {} }]);
    const r = await createJiraRequest({ ...cfg, summary: "S", description: "D", labels: ["x"], fetchImpl: f });
    assert.equal(r.issueKey, "POP-8");
    assert.match(r.labelsError, /400/);
});

// ── Un solo ticket por documento ────────────────────────────────────────
test("guarda la clave del ticket en el documento", async () => {
    const { ref, db } = fakeDoc({});
    let n = 0;
    const r = await ensureJiraTicket({ db, ref, ticket: {}, create: async () => { n++; return { issueKey: "POP-9", url: "u" }; } });
    assert.equal(r.issueKey, "POP-9");
    assert.equal(ref.data.jira.status, "created");
    assert.equal(ref.data.jira.issueKey, "POP-9");
    assert.equal(n, 1);
});

test("no duplica si el documento ya tiene ticket", async () => {
    const { ref, db } = fakeDoc({ jira: { issueKey: "POP-1", status: "created" } });
    const r = await ensureJiraTicket({ db, ref, ticket: {}, create: async () => assert.fail("no debía llamar a Jira") });
    assert.equal(r.skipped, true);
});

test("no duplica si otra ejecución está creando el ticket", async () => {
    const t0 = 1_000_000;
    const { ref, db } = fakeDoc({ jira: { status: "creating", claimedAtMs: t0 } });
    const r = await ensureJiraTicket({ db, ref, ticket: {}, now: () => t0 + 1000, create: async () => assert.fail("no debía llamar a Jira") });
    assert.equal(r.skipped, true);
});

test("reintenta si el intento anterior quedó colgado", async () => {
    const t0 = 1_000_000;
    const { ref, db } = fakeDoc({ jira: { status: "creating", claimedAtMs: t0 } });
    const r = await ensureJiraTicket({ db, ref, ticket: {}, now: () => t0 + CLAIM_STALE_MS + 1, create: async () => ({ issueKey: "POP-10" }) });
    assert.equal(r.issueKey, "POP-10");
});

test("si Jira falla, deja el error en el documento y permite reintentar", async () => {
    const { ref, db } = fakeDoc({});
    await assert.rejects(ensureJiraTicket({ db, ref, ticket: {}, create: async () => { throw new Error("Jira respondió 500"); } }), /500/);
    assert.equal(ref.data.jira.status, "failed");
    assert.match(ref.data.jira.error, /500/);
    const r = await ensureJiraTicket({ db, ref, ticket: {}, create: async () => ({ issueKey: "POP-11" }) });
    assert.equal(r.issueKey, "POP-11");
});
