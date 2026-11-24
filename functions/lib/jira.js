"use strict";

// Integración con Jira Service Management: cada reporte de problema
// (support_reports) y cada solicitud de proveedor (provider_requests) crea un
// ticket en el service desk de BeyGo. La lógica vive aquí, separada de las
// Cloud Functions, para poder probarla sin red ni Firestore
// (ver test/jira.test.js).

const SUMMARY_MAX = 240;
const DESCRIPTION_MAX = 30000;
// Si un intento quedó a medias (la función murió entre la reserva del turno y
// la respuesta de Jira), se permite reintentar pasado este tiempo.
const CLAIM_STALE_MS = 10 * 60 * 1000;

const REPORT_TYPE_LABELS = {
    chat_message: "reporte-chat",
};

function clean(value, fallback = "") {
    const text = `${value ?? ""}`.replace(/\s+/g, " ").trim();
    return text || fallback;
}

function truncate(text, max) {
    return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function slug(value) {
    return clean(value)
        .toLowerCase()
        .normalize("NFD")
        .replace(/[̀-ͯ]/g, "")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function formatDate(value) {
    if (!value) return "—";
    const date = typeof value.toDate === "function" ? value.toDate() : new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return date.toLocaleString("es-GT", { timeZone: "America/Guatemala" });
}

function lines(rows) {
    return rows
        .filter(([, v]) => v !== undefined && v !== null && `${v}`.trim() !== "")
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n");
}

/** Ticket para un documento de support_reports. */
function buildSupportReportTicket(reportId, data = {}) {
    const number = clean(data.reportNumber || data.reportId || reportId, "N/A");
    const type = clean(data.reportType, "Reporte");
    const subject = clean(data.subject, "Sin asunto");
    const isChat = data.reportType === "chat_message";

    const urls = Array.isArray(data.screenshotUrls) ? data.screenshotUrls.filter(Boolean) : [];
    const description = [
        isChat ? "Reporte de un mensaje de chat enviado desde BeyGo." : "Reporte de problema enviado desde BeyGo (apartado «Reportar un problema»).",
        "",
        lines([
            ["Número de reporte", number],
            ["Tipo", type],
            ["Asunto", subject],
            ["Correo del usuario", clean(data.userEmail, "—")],
            ["UID del usuario", clean(data.userId, "—")],
            ["Reservación", data.reservationId],
            ["Usuario reportado (UID)", data.reportedUid],
            ["Fecha", formatDate(data.createdAt)],
        ]),
        "",
        "Mensaje:",
        `${data.message ?? ""}`.trim() || "—",
        ...(urls.length ? ["", "Capturas de pantalla:", ...urls.map((u, i) => `${i + 1}. ${u}`)] : []),
    ].join("\n");

    const labels = ["beygo", isChat ? REPORT_TYPE_LABELS.chat_message : "reporte-conductor"];
    const typeLabel = slug(type);
    if (!isChat && typeLabel) labels.push(`tipo-${typeLabel}`);

    return {
        kind: "support",
        summary: truncate(`[${number}] ${type}: ${subject}`, SUMMARY_MAX),
        description: truncate(description, DESCRIPTION_MAX),
        labels,
    };
}

/** Ticket para un documento de provider_requests (alta de proveedor o baja de parqueo). */
function buildProviderRequestTicket(requestId, data = {}) {
    const isDeletion = data.requestType === "parking_deletion";
    const number = clean(data.requestNumber || data.requestId || requestId, requestId);
    const parking = clean(data.parkingName, "Parqueo sin nombre");

    if (isDeletion) {
        const description = [
            "Solicitud de un proveedor para dar de baja un parqueo en BeyGo.",
            "",
            lines([
                ["ID de la solicitud", requestId],
                ["Parqueo", parking],
                ["ID del parqueo", data.parkingId],
                ["UID del proveedor", clean(data.uid, "—")],
                ["Reservas activas", data.activeReservations],
                ["Reservas pendientes", data.pendingReservations],
                ["Fecha", formatDate(data.createdAt || data.requestedAt)],
            ]),
            "",
            "Motivo:",
            `${data.reason ?? ""}`.trim() || "—",
        ].join("\n");
        return {
            kind: "provider",
            summary: truncate(`[Baja de parqueo] ${parking}`, SUMMARY_MAX),
            description: truncate(description, DESCRIPTION_MAX),
            labels: ["beygo", "solicitud-proveedor", "baja-parqueo"],
        };
    }

    const hours = data.businessHours || {};
    const images = Array.isArray(data.parkingImages) ? data.parkingImages.length : 0;
    const hasCoords = typeof data.lat === "number" && typeof data.lng === "number";
    // Las fotos del DPI y de la patente NO se copian a Jira (datos personales):
    // se revisan en el panel de administración de BeyGo.
    const description = [
        "Solicitud para convertirse en proveedor (propietario de parqueo) en BeyGo.",
        "",
        lines([
            ["Número de solicitud", number],
            ["Parqueo", parking],
            ["Empresa", data.companyName],
            ["Correo", clean(data.email, "—")],
            ["Teléfono", data.phone],
            ["NIT", data.nit],
            ["Dirección", data.address],
            ["Capacidad", data.capacity],
            ["Precio por hora (Q)", data.pricePerHour],
            ["Cancelación gratuita (min)", data.freeCancellationMinutes],
            ["Horario", hours.open || hours.close ? `${hours.open || "?"} – ${hours.close || "?"}` : undefined],
            ["Ubicación", hasCoords ? `https://maps.google.com/?q=${data.lat},${data.lng}` : undefined],
            ["Fotos del parqueo", images ? `${images}` : undefined],
            ["UID del solicitante", clean(data.uid, "—")],
            ["Fecha", formatDate(data.createdAt)],
        ]),
        "",
        "Descripción:",
        `${data.description ?? ""}`.trim() || "—",
        "",
        "Documentos (DPI y patente): revisar en el panel de administración de BeyGo.",
    ].join("\n");

    return {
        kind: "provider",
        summary: truncate(`[${number}] Solicitud de proveedor: ${parking}`, SUMMARY_MAX),
        description: truncate(description, DESCRIPTION_MAX),
        labels: ["beygo", "solicitud-proveedor", "alta-proveedor"],
    };
}

/** Crea la solicitud en Jira Service Management y devuelve su clave (p. ej. POP-12). */
async function createJiraRequest({
    baseUrl, email, token, serviceDeskId, requestTypeId,
    summary, description, labels = [], fetchImpl = fetch,
}) {
    if (!baseUrl || !email || !token) throw new Error("Faltan JIRA_BASE_URL, JIRA_EMAIL o JIRA_API_TOKEN.");
    const root = baseUrl.replace(/\/+$/, "");
    const headers = {
        Authorization: `Basic ${Buffer.from(`${email}:${token}`).toString("base64")}`,
        "Content-Type": "application/json",
        Accept: "application/json",
    };

    const res = await fetchImpl(`${root}/rest/servicedeskapi/request`, {
        method: "POST",
        headers,
        body: JSON.stringify({
            serviceDeskId: `${serviceDeskId}`,
            requestTypeId: `${requestTypeId}`,
            requestFieldValues: { summary, description },
        }),
    });
    if (!res.ok) {
        const body = await res.text().catch(() => "");
        throw new Error(`Jira respondió ${res.status} al crear la solicitud: ${body.slice(0, 500)}`);
    }
    const created = await res.json();
    const issueKey = created.issueKey;
    if (!issueKey) throw new Error("Jira no devolvió issueKey.");

    let labelsError = null;
    if (labels.length) {
        const upd = await fetchImpl(`${root}/rest/api/3/issue/${encodeURIComponent(issueKey)}`, {
            method: "PUT",
            headers,
            body: JSON.stringify({ update: { labels: labels.map((l) => ({ add: l })) } }),
        });
        if (!upd.ok) {
            // El ticket ya existe: no se reintenta por las etiquetas.
            labelsError = `Etiquetas no aplicadas (${upd.status}): ${(await upd.text().catch(() => "")).slice(0, 300)}`;
        }
    }
    return { issueKey, issueId: created.issueId, url: `${root}/browse/${issueKey}`, labelsError };
}

/**
 * Crea el ticket una sola vez por documento. Reserva el turno en una
 * transacción (campo `jira.status = "creating"`) para que dos ejecuciones del
 * mismo evento no dupliquen el ticket, y guarda el resultado en `jira`.
 */
async function ensureJiraTicket({ db, ref, ticket, create, now = () => Date.now(), serverTimestamp }) {
    const claimed = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const jira = (snap.exists ? snap.data()?.jira : null) || {};
        if (jira.issueKey) return false;
        if (jira.status === "creating" && now() - (jira.claimedAtMs || 0) < CLAIM_STALE_MS) return false;
        tx.set(ref, { jira: { status: "creating", claimedAtMs: now() } }, { merge: true });
        return true;
    });
    if (!claimed) return { skipped: true };

    try {
        const result = await create(ticket);
        await ref.set({
            jira: {
                status: "created",
                issueKey: result.issueKey,
                url: result.url,
                createdAt: serverTimestamp ? serverTimestamp() : new Date(now()),
                ...(result.labelsError ? { warning: result.labelsError } : {}),
            },
        }, { merge: true });
        return { skipped: false, ...result };
    } catch (error) {
        await ref.set({
            jira: {
                status: "failed",
                error: `${error instanceof Error ? error.message : error}`.slice(0, 1000),
                failedAt: serverTimestamp ? serverTimestamp() : new Date(now()),
            },
        }, { merge: true });
        throw error;
    }
}

module.exports = {
    buildSupportReportTicket,
    buildProviderRequestTicket,
    createJiraRequest,
    ensureJiraTicket,
    CLAIM_STALE_MS,
};
