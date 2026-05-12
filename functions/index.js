// functions/index.js
//
// Firebase Cloud Functions — Push Notifications
//
// Triggers on reservation document writes and sends FCM to the
// correct recipient based on what changed.
//
// SETUP:
//   1. firebase init functions  (choose JavaScript)
//   2. Copy this file to functions/index.js
//   3. npm install firebase-admin firebase-functions
//   4. firebase deploy --only functions
//   5. Enable Firebase Blaze plan (required for Cloud Functions)
//
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const PDFDocument = require("pdfkit");

admin.initializeApp();
const db = admin.firestore();

const OTP_TTL_MINUTES = 10;
const OTP_COLLECTION = "owner_security_otp";
const ownerSecurityEmail = defineSecret("OWNER_SECURITY_EMAIL");
const ownerSecurityEmailPassword = defineSecret("OWNER_SECURITY_EMAIL_PASSWORD");

function getMailTransport() {
    const user = ownerSecurityEmail.value();
    const pass = ownerSecurityEmailPassword.value();

    if (!user || !pass) {
        throw new Error(
            "Missing OWNER_SECURITY_EMAIL / OWNER_SECURITY_EMAIL_PASSWORD secrets"
        );
    }

    return nodemailer.createTransport({
        service: "gmail",
        auth: { user, pass },
    });
}

function hashValue(value) {
    return crypto.createHash("sha256").update(value).digest("hex");
}

function generateOtpCode() {
    return `${Math.floor(100000 + Math.random() * 900000)}`;
}

function generateResetToken() {
    return crypto.randomBytes(24).toString("hex");
}

async function sendMailSafe({ to, subject, text, html, attachments = [] }) {
    if (!to) return;
    const transport = getMailTransport();
    await transport.sendMail({
        from: ownerSecurityEmail.value(),
        to,
        subject,
        text,
        html,
        attachments,
    });
}

async function assertOwnerUser(uid) {
    const parkingSnap = await db
        .collection("parkings")
        .where("ownerID", "==", uid)
        .limit(1)
        .get();

    if (parkingSnap.empty) {
        throw new HttpsError(
            "permission-denied",
            "Solo los owners pueden usar esta operación."
        );
    }

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() || {};
    const email = userData.email;

    if (!email) {
        throw new HttpsError(
            "failed-precondition",
            "No se encontró un correo válido para este owner."
        );
    }

    const displayName = `${userData.displayName || userData.name || ""}`.trim();

    return { email, displayName };
}

const REPORT_TIMEZONE = "America/Guatemala";
const REPORT_MONTHS_ES = [
    "enero",
    "febrero",
    "marzo",
    "abril",
    "mayo",
    "junio",
    "julio",
    "agosto",
    "septiembre",
    "octubre",
    "noviembre",
    "diciembre",
];

function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date, days) {
    return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function startOfMonth(date) {
    return new Date(date.getFullYear(), date.getMonth(), 1);
}

function startOfNextMonth(date) {
    return new Date(date.getFullYear(), date.getMonth() + 1, 1);
}

function parseInputDate(value) {
    if (!value) return null;
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return null;
    return parsed;
}

function formatDateTimeGt(date) {
    if (!date) return "—";
    return new Intl.DateTimeFormat("es-GT", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: REPORT_TIMEZONE,
    }).format(date).replace(",", "");
}

function formatShortDateGt(date) {
    if (!date) return "—";
    return new Intl.DateTimeFormat("es-GT", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        timeZone: REPORT_TIMEZONE,
    }).format(date);
}

function formatCurrencyQ(value) {
    if (value == null || Number.isNaN(Number(value))) return "—";
    return `Q ${Number(value).toFixed(2)}`;
}

function escapeHtml(value) {
    return `${value ?? ""}`
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function normalizeReportRange(periodType, rawStartDate, rawEndDate) {
    const now = new Date();

    if (periodType === "current_month") {
        const start = startOfMonth(now);
        const endExclusive = startOfNextMonth(now);
        return {
            start,
            endExclusive,
            periodLabel: `${REPORT_MONTHS_ES[start.getMonth()]} ${start.getFullYear()}`,
            fileLabel: `${start.getFullYear()}-${`${start.getMonth() + 1}`.padStart(2, "0")}`,
        };
    }

    if (periodType === "previous_month") {
        const currentMonthStart = startOfMonth(now);
        const start = new Date(
            currentMonthStart.getFullYear(),
            currentMonthStart.getMonth() - 1,
            1
        );
        return {
            start,
            endExclusive: currentMonthStart,
            periodLabel: `${REPORT_MONTHS_ES[start.getMonth()]} ${start.getFullYear()}`,
            fileLabel: `${start.getFullYear()}-${`${start.getMonth() + 1}`.padStart(2, "0")}`,
        };
    }

    if (periodType === "custom") {
        const parsedStart = parseInputDate(rawStartDate);
        const parsedEnd = parseInputDate(rawEndDate);

        if (!parsedStart || !parsedEnd) {
            throw new HttpsError(
                "invalid-argument",
                "Debes indicar un rango válido para el reporte."
            );
        }

        const start = startOfDay(parsedStart);
        const end = startOfDay(parsedEnd);

        if (end.getTime() < start.getTime()) {
            throw new HttpsError(
                "invalid-argument",
                "La fecha final no puede ser menor que la inicial."
            );
        }

        return {
            start,
            endExclusive: addDays(end, 1),
            periodLabel: `${formatShortDateGt(start)} - ${formatShortDateGt(end)}`,
            fileLabel: `${start.getFullYear()}-${`${start.getMonth() + 1}`.padStart(2, "0")}-custom`,
        };
    }

    throw new HttpsError("invalid-argument", "Periodo de reporte no válido.");
}

function getRecordStateLabel(record) {
    if (record.type === "manual") return "Presencial";
    if (record.state === "completed") return "Completada";
    if (record.state === "cancelled" && record.cancellationPenaltyApplied) {
        return "Cancelada con penalización";
    }
    if (record.state === "cancelled") return "Cancelada";
    if (record.state === "cancellation_requested") return "Solicitud cancelación";
    return `${record.state || "Sin estado"}`;
}

function buildHistorySummary(recordCount) {
    if (recordCount === 0) {
        return "No se registraron movimientos en el período.";
    }
    if (recordCount === 1) {
        return "Se registró 1 movimiento en el período.";
    }
    return `Se registraron ${recordCount} movimientos en el período.`;
}

async function buildOwnerHistoryReportDataset({
    uid,
    start,
    endExclusive,
}) {
    const { email, displayName } = await assertOwnerUser(uid);

    const parkingSnap = await db
        .collection("parkings")
        .where("ownerID", "==", uid)
        .get();

    if (parkingSnap.empty) {
        throw new HttpsError(
            "failed-precondition",
            "No se encontró un parqueo asociado a este owner."
        );
    }

    const parkingDocs = parkingSnap.docs;
    const parkingNames = parkingDocs
        .map((doc) => `${doc.data()?.name || ""}`.trim())
        .filter(Boolean);
    const parkingLabel =
        parkingNames.length <= 1
            ? parkingNames[0] || "tu parqueo"
            : `${parkingNames[0]} y ${parkingNames.length - 1} parqueo(s) más`;

    const reservationsSnap = await db
        .collection("reservations")
        .where("ownerId", "==", uid)
        .where("reservedAt", ">=", admin.firestore.Timestamp.fromDate(start))
        .where("reservedAt", "<", admin.firestore.Timestamp.fromDate(endExclusive))
        .orderBy("reservedAt", "desc")
        .get();

    const onlineRecords = reservationsSnap.docs
        .map((doc) => {
            const data = doc.data() || {};
            const state = `${data.state || ""}`.trim();
            const cancellationPenaltyApplied =
                data.cancellationPenaltyApplied === true;

            if (
                state !== "completed" &&
                state !== "cancelled" &&
                state !== "cancellation_requested"
            ) {
                return null;
            }

            return {
                id: doc.id,
                type: "online",
                reservationNumber: `${data.reservationNumber || "N/A"}`,
                customerName: `${data.userName || "N/A"}`,
                plate: `${data.plate || "N/A"}`,
                spaceNumber: Number(data.spaceNumber || 0),
                reservedAt: data.reservedAt?.toDate?.() || null,
                endedAt:
                    data.endedAt?.toDate?.() ||
                    data.exitApprovedAt?.toDate?.() ||
                    null,
                state,
                cancellationPenaltyApplied,
                cancellationReason: `${data.cancellationReason || ""}`.trim(),
                amount:
                    data.amount != null
                        ? Number(data.amount)
                        : data.estimatedAmount != null
                        ? Number(data.estimatedAmount)
                        : null,
                parkingName: `${data.parkingName || ""}`.trim(),
            };
        })
        .filter(Boolean);

    const walkInGroups = await Promise.all(
        parkingDocs.map(async (parkingDoc) => {
            const snap = await parkingDoc.ref
                .collection("walk_ins")
                .where("enteredAt", ">=", admin.firestore.Timestamp.fromDate(start))
                .where("enteredAt", "<", admin.firestore.Timestamp.fromDate(endExclusive))
                .orderBy("enteredAt", "desc")
                .get();

            return snap.docs
                .map((doc) => {
                    const data = doc.data() || {};
                    if (`${data.status || ""}`.trim() !== "completed") {
                        return null;
                    }

                    return {
                        id: doc.id,
                        type: "manual",
                        reservationNumber: `${data.reservationNumber || "MAN-SIN-NUMERO"}`,
                        customerName: `${data.customerName || "Cliente"}`,
                        plate: `${data.plate || "N/A"}`,
                        spaceNumber: Number(data.spaceNumber || 0),
                        reservedAt: data.enteredAt?.toDate?.() || null,
                        endedAt: data.exitAt?.toDate?.() || null,
                        state: "manual_completed",
                        cancellationPenaltyApplied: false,
                        cancellationReason: "",
                        amount:
                            data.amount != null
                                ? Number(data.amount)
                                : null,
                        parkingName: `${parkingDoc.data()?.name || ""}`.trim(),
                    };
                })
                .filter(Boolean);
        })
    );

    const records = [...onlineRecords, ...walkInGroups.flat()]
        .filter((record) => record?.reservedAt)
        .sort((a, b) => b.reservedAt.getTime() - a.reservedAt.getTime());

    const kpis = {
        totalMovements: records.length,
        completed:
            records.filter((record) => record.type === "online" && record.state === "completed")
                .length,
        cancelled:
            records.filter((record) => record.state === "cancelled").length,
        cancelledPenalty:
            records.filter(
                (record) =>
                    record.state === "cancelled" &&
                    record.cancellationPenaltyApplied
            ).length,
        manual:
            records.filter((record) => record.type === "manual").length,
        revenueTotal: records.reduce(
            (sum, record) => sum + (Number(record.amount) || 0),
            0
        ),
    };

    return {
        uid,
        email,
        ownerName: displayName || "Owner BeyGo",
        parkingLabel,
        parkingCount: parkingDocs.length,
        records,
        kpis,
    };
}

function buildHistoryReportHtml({
    ownerName,
    parkingLabel,
    periodLabel,
    summaryText,
    kpis,
    records,
}) {
    const rowsHtml = records
        .slice(0, 10)
        .map((record) => {
            return `
              <tr>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${escapeHtml(record.reservationNumber)}</td>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${escapeHtml(record.type === "manual" ? "Presencial" : "En línea")}</td>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${escapeHtml(getRecordStateLabel(record))}</td>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${escapeHtml(record.customerName)}</td>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${escapeHtml(record.plate)}</td>
                <td style="padding:10px;border-bottom:1px solid #E5E7EB;">${formatCurrencyQ(record.amount)}</td>
              </tr>
            `;
        })
        .join("");

    return `
      <div style="font-family:Arial,sans-serif;background:#F8FAFC;padding:24px;color:#0F172A">
        <div style="max-width:760px;margin:0 auto;background:white;border-radius:20px;overflow:hidden;border:1px solid #E5E7EB">
          <div style="background:linear-gradient(180deg,#3B5F9A,#1E3A5F);padding:28px;color:white">
            <div style="font-size:28px;font-weight:800;margin-bottom:8px;">Resumen mensual BeyGo</div>
            <div style="font-size:15px;opacity:.92;">${escapeHtml(periodLabel)}</div>
          </div>
          <div style="padding:24px">
            <p style="margin:0 0 10px;font-size:15px;">Hola <strong>${escapeHtml(ownerName)}</strong>,</p>
            <p style="margin:0 0 12px;font-size:14px;color:#334155;">
              Aquí tienes el resumen de historial de <strong>${escapeHtml(parkingLabel)}</strong>.
            </p>
            <p style="margin:0 0 18px;font-size:14px;color:#334155;">${escapeHtml(summaryText)}</p>

            <div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:20px;">
              ${[
        ["Movimientos", kpis.totalMovements],
        ["Completadas", kpis.completed],
        ["Canceladas", kpis.cancelled],
        ["Canceladas c/ penalización", kpis.cancelledPenalty],
        ["Presenciales", kpis.manual],
        ["Ingresos", formatCurrencyQ(kpis.revenueTotal)],
    ].map(([label, value]) => `
                <div style="background:#F8FAFC;border:1px solid #E5E7EB;border-radius:14px;padding:14px;">
                  <div style="font-size:12px;color:#64748B;margin-bottom:6px;">${escapeHtml(label)}</div>
                  <div style="font-size:20px;font-weight:800;color:#1E3A5F;">${escapeHtml(value)}</div>
                </div>
              `).join("")}
            </div>

            <div style="font-size:13px;font-weight:700;color:#0F172A;margin-bottom:10px;">Últimos movimientos del período</div>
            <table style="width:100%;border-collapse:collapse;font-size:13px;">
              <thead>
                <tr style="background:#F8FAFC;color:#475569;text-align:left;">
                  <th style="padding:10px;">No.</th>
                  <th style="padding:10px;">Tipo</th>
                  <th style="padding:10px;">Estado</th>
                  <th style="padding:10px;">Cliente</th>
                  <th style="padding:10px;">Placa</th>
                  <th style="padding:10px;">Monto</th>
                </tr>
              </thead>
              <tbody>
                ${rowsHtml || `
                  <tr>
                    <td colspan="6" style="padding:14px;color:#64748B;">No hubo movimientos para mostrar.</td>
                  </tr>
                `}
              </tbody>
            </table>

            <p style="margin:18px 0 0;font-size:13px;color:#475569;">
              Adjuntamos un PDF con el detalle completo del período.
            </p>
          </div>
        </div>
      </div>
    `;
}

function generateHistoryReportPdf({
    ownerName,
    parkingLabel,
    periodLabel,
    generatedAt,
    kpis,
    records,
}) {
    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({
            size: "A4",
            layout: "landscape",
            margin: 36,
        });
        const chunks = [];
        doc.on("data", (chunk) => chunks.push(chunk));
        doc.on("end", () => resolve(Buffer.concat(chunks)));
        doc.on("error", reject);

        const pageWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
        const left = doc.page.margins.left;

        doc.fillColor("#1E3A5F").fontSize(24).font("Helvetica-Bold")
            .text("BeyGo - Resumen de historial", left, 34, { width: pageWidth });
        doc.moveDown(0.3);
        doc.fillColor("#334155").fontSize(12).font("Helvetica")
            .text(`Owner: ${ownerName}`, left, doc.y, { width: pageWidth });
        doc.text(`Parqueo: ${parkingLabel}`, left, doc.y + 2, { width: pageWidth });
        doc.text(`Período: ${periodLabel}`, left, doc.y + 2, { width: pageWidth });
        doc.text(`Generado: ${formatDateTimeGt(generatedAt)}`, left, doc.y + 2, { width: pageWidth });

        const metrics = [
            ["Movimientos", `${kpis.totalMovements}`],
            ["Completadas", `${kpis.completed}`],
            ["Canceladas", `${kpis.cancelled}`],
            ["Canceladas c/ penalización", `${kpis.cancelledPenalty}`],
            ["Presenciales", `${kpis.manual}`],
            ["Ingresos", formatCurrencyQ(kpis.revenueTotal)],
        ];

        let metricX = left;
        const metricY = 128;
        const metricW = (pageWidth - 20) / 3;
        const metricH = 52;

        metrics.forEach(([label, value], index) => {
            const row = Math.floor(index / 3);
            const col = index % 3;
            const x = metricX + (metricW + 10) * col;
            const y = metricY + (metricH + 10) * row;

            doc.roundedRect(x, y, metricW, metricH, 12).fillAndStroke("#F8FAFC", "#E2E8F0");
            doc.fillColor("#64748B").font("Helvetica").fontSize(10)
                .text(label, x + 12, y + 10, { width: metricW - 24 });
            doc.fillColor("#1E3A5F").font("Helvetica-Bold").fontSize(16)
                .text(value, x + 12, y + 24, { width: metricW - 24 });
        });

        let y = metricY + metricH * 2 + 30;
        const headers = [
            { key: "reservationNumber", label: "No.", width: 82 },
            { key: "type", label: "Tipo", width: 62 },
            { key: "state", label: "Estado", width: 118 },
            { key: "customerName", label: "Cliente", width: 120 },
            { key: "plate", label: "Placa", width: 72 },
            { key: "spaceNumber", label: "Esp.", width: 42 },
            { key: "reservedAt", label: "Inicio", width: 96 },
            { key: "endedAt", label: "Fin", width: 96 },
            { key: "amount", label: "Monto", width: 70 },
        ];

        function drawTableHeader() {
            doc.fillColor("#F8FAFC").rect(left, y, pageWidth, 24).fill();
            let x = left + 8;
            headers.forEach((header) => {
                doc.fillColor("#334155").font("Helvetica-Bold").fontSize(9)
                    .text(header.label, x, y + 7, { width: header.width - 6 });
                x += header.width;
            });
            y += 28;
        }

        drawTableHeader();

        records.forEach((record) => {
            const rowHeight = record.cancellationReason ? 34 : 22;
            if (y + rowHeight > doc.page.height - 44) {
                doc.addPage();
                y = 40;
                drawTableHeader();
            }

            doc.strokeColor("#E2E8F0")
                .moveTo(left, y - 4)
                .lineTo(left + pageWidth, y - 4)
                .stroke();

            const values = {
                reservationNumber: record.reservationNumber,
                type: record.type === "manual" ? "Manual" : "En línea",
                state: getRecordStateLabel(record),
                customerName: record.customerName,
                plate: record.plate,
                spaceNumber: `${record.spaceNumber}`,
                reservedAt: formatDateTimeGt(record.reservedAt),
                endedAt: formatDateTimeGt(record.endedAt),
                amount: formatCurrencyQ(record.amount),
            };

            let x = left + 8;
            headers.forEach((header) => {
                doc.fillColor("#0F172A").font("Helvetica").fontSize(8.5)
                    .text(`${values[header.key] || "—"}`, x, y, {
                        width: header.width - 6,
                        ellipsis: true,
                    });
                x += header.width;
            });

            if (record.cancellationReason) {
                doc.fillColor("#64748B").font("Helvetica-Oblique").fontSize(7.5)
                    .text(
                        `Motivo: ${record.cancellationReason}`,
                        left + 8,
                        y + 14,
                        { width: pageWidth - 16, ellipsis: true }
                    );
            }

            y += rowHeight;
        });

        doc.end();
    });
}

async function sendOwnerHistorySummaryEmail({
    to,
    ownerName,
    parkingLabel,
    periodLabel,
    fileLabel,
    records,
    kpis,
    isAutomatic,
}) {
    const generatedAt = new Date();
    const summaryText = buildHistorySummary(records.length);
    const subject = isAutomatic
        ? `BeyGo: resumen mensual de ${periodLabel}`
        : `BeyGo: resumen de historial - ${periodLabel}`;

    const html = buildHistoryReportHtml({
        ownerName,
        parkingLabel,
        periodLabel,
        summaryText,
        kpis,
        records,
    });

    const text =
        `Hola ${ownerName},\n\n` +
        `Adjuntamos tu resumen de historial de BeyGo.\n` +
        `Período: ${periodLabel}\n` +
        `Parqueo: ${parkingLabel}\n\n` +
        `${summaryText}\n\n` +
        `Movimientos: ${kpis.totalMovements}\n` +
        `Completadas: ${kpis.completed}\n` +
        `Canceladas: ${kpis.cancelled}\n` +
        `Canceladas con penalización: ${kpis.cancelledPenalty}\n` +
        `Presenciales: ${kpis.manual}\n` +
        `Ingresos: ${formatCurrencyQ(kpis.revenueTotal)}\n\n` +
        `Adjuntamos un PDF con el detalle completo del período.`;

    const pdfBuffer = await generateHistoryReportPdf({
        ownerName,
        parkingLabel,
        periodLabel,
        generatedAt,
        kpis,
        records,
    });

    await sendMailSafe({
        to,
        subject,
        text,
        html,
        attachments: [{
            filename: `beygo-resumen-${fileLabel}.pdf`,
            content: pdfBuffer,
            contentType: "application/pdf",
        }],
    });
}

async function assertReservationOwnerAction(uid, reservationId) {
    const reservationRef = db.collection("reservations").doc(reservationId);
    const reservationSnap = await reservationRef.get();

    if (!reservationSnap.exists) {
        throw new HttpsError("not-found", "La reservación ya no existe.");
    }

    const reservation = reservationSnap.data() || {};
    const ownerId = `${reservation.ownerId || ""}`.trim();
    const parkingId = `${reservation.parkingId || ""}`.trim();

    let allowed = ownerId === uid;

    if (!allowed && parkingId) {
        const parkingSnap = await db.collection("parkings").doc(parkingId).get();
        const parkingOwnerId = `${parkingSnap.data()?.ownerID || ""}`.trim();
        allowed = parkingOwnerId === uid;
    }

    if (!allowed) {
        throw new HttpsError(
            "permission-denied",
            "No tienes permisos para gestionar esta reservación."
        );
    }

    return { reservationRef };
}

exports.requestOwnerRevenuePinOtp = onCall({
    secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async (request) => {
    if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const uid = request.auth.uid;

    try {
        const { email } = await assertOwnerUser(uid);
        console.log(
            `[owner-pin-otp] Preparing OTP for uid=${uid} email=${email}`
        );

        const code = generateOtpCode();
        const codeHash = hashValue(code);
        const expiresAt = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000)
        );

        await db.collection(OTP_COLLECTION).doc(uid).set({
            purpose: "owner_revenue_pin_reset",
            email,
            codeHash,
            attempts: 0,
            expiresAt,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            verifiedAt: null,
            resetTokenHash: null,
        });

        const transport = getMailTransport();
        await transport.verify();
        console.log(`[owner-pin-otp] SMTP verified for ${ownerSecurityEmail.value()}`);

        await transport.sendMail({
            from: ownerSecurityEmail.value(),
            to: email,
            subject: "Codigo OTP para restablecer tu PIN",
            text:
                `Tu codigo de verificacion es: ${code}\n\n` +
                `Este codigo vence en ${OTP_TTL_MINUTES} minutos.\n` +
                `Si no solicitaste este cambio, ignora este correo.`,
            html:
                `<div style="font-family:Arial,sans-serif;padding:16px">` +
                `<h2>Restablecer PIN de ingresos</h2>` +
                `<p>Tu codigo de verificacion es:</p>` +
                `<div style="font-size:32px;font-weight:800;letter-spacing:6px;margin:16px 0">${code}</div>` +
                `<p>Este codigo vence en ${OTP_TTL_MINUTES} minutos.</p>` +
                `<p>Si no solicitaste este cambio, puedes ignorar este correo.</p>` +
                `</div>`,
        });

        console.log(`[owner-pin-otp] OTP email sent to ${email}`);
        return {
            ok: true,
            emailMasked: email.replace(/(.{2}).+(@.+)/, "$1***$2"),
            expiresInMinutes: OTP_TTL_MINUTES,
        };
    } catch (error) {
        console.error("[owner-pin-otp] Request failed", error);

        if (error instanceof HttpsError) {
            throw error;
        }

        if (
            error?.code === "EAUTH" ||
            error?.responseCode === 535
        ) {
            throw new HttpsError(
                "failed-precondition",
                "El correo emisor OTP no pudo autenticarse en Gmail. Revisa OWNER_SECURITY_EMAIL y su App Password."
            );
        }

        throw new HttpsError(
            "internal",
            "No se pudo enviar el correo OTP en este momento."
        );
    }
});

exports.verifyOwnerRevenuePinOtp = onCall(async (request) => {
    if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const uid = request.auth.uid;
    const code = `${request.data?.code ?? ""}`.trim();

    if (!/^\d{6}$/.test(code)) {
        throw new HttpsError(
            "invalid-argument",
            "Ingresa un codigo OTP valido de 6 digitos."
        );
    }

    await assertOwnerUser(uid);

    const docRef = db.collection(OTP_COLLECTION).doc(uid);
    const otpSnap = await docRef.get();
    const otpData = otpSnap.data();

    if (!otpSnap.exists || !otpData) {
        throw new HttpsError(
            "failed-precondition",
            "No hay un OTP activo para verificar."
        );
    }

    const expiresAt = otpData.expiresAt?.toDate?.();
    if (!expiresAt || expiresAt.getTime() < Date.now()) {
      await docRef.delete().catch(() => null);
        throw new HttpsError("deadline-exceeded", "El codigo ya vencio.");
    }

    const attempts = Number(otpData.attempts || 0);
    if (attempts >= 5) {
        await docRef.delete().catch(() => null);
        throw new HttpsError(
            "resource-exhausted",
            "Demasiados intentos. Solicita un nuevo codigo."
        );
    }

    if (hashValue(code) !== otpData.codeHash) {
        await docRef.update({
            attempts: attempts + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw new HttpsError("permission-denied", "Codigo incorrecto.");
    }

    const resetToken = generateResetToken();
    await docRef.update({
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        resetTokenHash: hashValue(resetToken),
        attempts: attempts + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        ok: true,
        resetToken,
    };
});

exports.ownerForceFinalizeReservation = onCall(async (request) => {
    if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const uid = request.auth.uid;
    const reservationId = `${request.data?.reservationId ?? ""}`.trim();
    const rawReason = `${request.data?.reason ?? ""}`.trim();
    const reason =
        rawReason.length > 0
            ? rawReason.slice(0, 200)
            : "Cancelado por el propietario";

    if (!reservationId) {
        throw new HttpsError(
            "invalid-argument",
            "Falta el identificador de la reservación."
        );
    }

    const { reservationRef } = await assertReservationOwnerAction(uid, reservationId);
    const now = new Date();

    await db.runTransaction(async (tx) => {
        const reservationSnap = await tx.get(reservationRef);
        if (!reservationSnap.exists) {
            throw new HttpsError("not-found", "La reservación ya no existe.");
        }

        const latest = reservationSnap.data() || {};
        const state = `${latest.state || ""}`.trim();

        if (state !== "active" && state !== "pending") {
            throw new HttpsError(
                "failed-precondition",
                "La reservación no puede ser finalizada."
            );
        }

        const userId = `${latest.userId || ""}`.trim();
        const parkingId = `${latest.parkingId || ""}`.trim();
        const spaceNumber = latest.spaceNumber;

        if (!userId || !parkingId || typeof spaceNumber !== "number") {
            throw new HttpsError(
                "failed-precondition",
                "La reservación no tiene datos suficientes para finalizarse."
            );
        }

        const controlRef = db
            .collection("users")
            .doc(userId)
            .collection("reservation_control")
            .doc("main");
        const spaceRef = db
            .collection("parkings")
            .doc(parkingId)
            .collection("spaces")
            .doc(`${spaceNumber}`);
        const controlSnap = await tx.get(controlRef);
        const spaceSnap = await tx.get(spaceRef);
        const controlData = controlSnap.data() || {};
        const spaceData = spaceSnap.data() || {};

        const currentAttempts = Number(controlData.cancelAttempts || 0);
        const nextAttempts = currentAttempts + 1;
        const maxAttempts = 2;
        const cooldownDays = 15;
        const limitReached = nextAttempts >= maxAttempts;
        const restrictedUntil = limitReached
            ? admin.firestore.Timestamp.fromDate(
                new Date(now.getTime() + cooldownDays * 24 * 60 * 60 * 1000)
            )
            : null;

        tx.update(reservationRef, {
            state: "cancelled",
            endedAt: admin.firestore.Timestamp.fromDate(now),
            cancellationReason: reason,
            cancelledBy: "owner",
            cancellationPenaltyApplied: true,
            providerApprovalStatus: "approved",
            cancelAttempts: Number(latest.cancelAttempts || 0) + 1,
            userCancelAttempts: nextAttempts,
            restrictedUntil,
        });

        if (controlSnap.exists) {
            tx.update(controlRef, {
                cancelAttempts: nextAttempts,
                restrictedUntil,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } else {
            tx.set(controlRef, {
                userId,
                cancelAttempts: nextAttempts,
                restrictedUntil,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        const currentStatus = `${spaceData.status || "free"}`
            .toLowerCase()
            .trim();

        if (
            (currentStatus === "occupied" || currentStatus === "requested") &&
            spaceData.currentReservationId === reservationId
        ) {
            tx.set(
                spaceRef,
                {
                    status: "free",
                    currentReservationId: null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );
        }
    });

    return { ok: true };
});

exports.sendOwnerHistoryReport = onCall({
    secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async (request) => {
    if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const uid = request.auth.uid;
    const periodType = `${request.data?.periodType || ""}`.trim();
    const startDate = request.data?.startDate;
    const endDate = request.data?.endDate;

    const { start, endExclusive, periodLabel, fileLabel } = normalizeReportRange(
        periodType,
        startDate,
        endDate
    );

    const dataset = await buildOwnerHistoryReportDataset({
        uid,
        start,
        endExclusive,
    });

    if (dataset.records.length === 0) {
        throw new HttpsError(
            "failed-precondition",
            "No hay movimientos en ese período para generar el reporte."
        );
    }

    await sendOwnerHistorySummaryEmail({
        to: dataset.email,
        ownerName: dataset.ownerName,
        parkingLabel: dataset.parkingLabel,
        periodLabel,
        fileLabel,
        records: dataset.records,
        kpis: dataset.kpis,
        isAutomatic: false,
    });

    return {
        ok: true,
        email: dataset.email,
        recordCount: dataset.records.length,
        periodLabel,
    };
});

exports.sendOwnerMonthlyHistoryReports = onSchedule({
    schedule: "0 7 1 * *",
    timeZone: REPORT_TIMEZONE,
    secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async () => {
    const { start, endExclusive, periodLabel, fileLabel } = normalizeReportRange(
        "previous_month"
    );

    const parkingsSnap = await db.collection("parkings").get();
    const ownerIds = [...new Set(
        parkingsSnap.docs
            .map((doc) => `${doc.data()?.ownerID || ""}`.trim())
            .filter(Boolean)
    )];

    for (const uid of ownerIds) {
        try {
            const dataset = await buildOwnerHistoryReportDataset({
                uid,
                start,
                endExclusive,
            });

            if (dataset.records.length === 0) {
                continue;
            }

            await sendOwnerHistorySummaryEmail({
                to: dataset.email,
                ownerName: dataset.ownerName,
                parkingLabel: dataset.parkingLabel,
                periodLabel,
                fileLabel,
                records: dataset.records,
                kpis: dataset.kpis,
                isAutomatic: true,
            });

            console.log(
                `[owner-history-report] Sent monthly report to ${dataset.email} (${dataset.records.length} records)`
            );
        } catch (error) {
            console.error(
                `[owner-history-report] Failed for owner ${uid}:`,
                error
            );
        }
    }
});

exports.onSupportReportCreated = onDocumentCreated({
    document: "support_reports/{reportId}",
    secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const to = `${data.userEmail || ""}`.trim();
    if (!to) return;

    const reportNumber = `${data.reportNumber || data.reportId || "N/A"}`;
    const reportType = `${data.reportType || "Reporte"}`;
    const subjectLine = `${data.subject || "Sin asunto"}`;

    await sendMailSafe({
        to,
        subject: `BeyGo: recibimos tu reporte ${reportNumber}`,
        text:
            `Hola,\n\n` +
            `Recibimos tu reporte en BeyGo correctamente.\n\n` +
            `Número de reporte: ${reportNumber}\n` +
            `Tipo: ${reportType}\n` +
            `Asunto: ${subjectLine}\n\n` +
            `Nuestro equipo revisará el caso y te dará seguimiento si es necesario.\n\n` +
            `Gracias por ayudarnos a mejorar BeyGo.`,
        html:
            `<div style="font-family:Arial,sans-serif;padding:16px">` +
            `<h2>Reporte recibido</h2>` +
            `<p>Recibimos tu reporte en <strong>BeyGo</strong> correctamente.</p>` +
            `<p><strong>Número de reporte:</strong> ${reportNumber}</p>` +
            `<p><strong>Tipo:</strong> ${reportType}</p>` +
            `<p><strong>Asunto:</strong> ${subjectLine}</p>` +
            `<p>Nuestro equipo revisará el caso y te dará seguimiento si es necesario.</p>` +
            `<p>Gracias por ayudarnos a mejorar BeyGo.</p>` +
            `</div>`,
    });
});

exports.onProviderRequestCreated = onDocumentCreated({
    document: "provider_requests/{requestId}",
    secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const to = `${data.email || ""}`.trim();
    if (!to) return;

    const requestNumber = `${data.requestNumber || data.requestId || "N/A"}`;
    const parkingName = `${data.parkingName || "tu parqueo"}`;

    await sendMailSafe({
        to,
        subject: `BeyGo: recibimos tu solicitud ${requestNumber}`,
        text:
            `Hola,\n\n` +
            `Tu solicitud para convertirte en propietario de ${parkingName} fue enviada correctamente.\n\n` +
            `Número de solicitud: ${requestNumber}\n` +
            `Parqueo: ${parkingName}\n\n` +
            `Nuestro equipo de soporte revisará tu información y se pondrá en contacto contigo para continuar el proceso.\n\n` +
            `Gracias por confiar en BeyGo.`,
        html:
            `<div style="font-family:Arial,sans-serif;padding:16px">` +
            `<h2>Solicitud recibida</h2>` +
            `<p>Tu solicitud para convertirte en <strong>propietario de ${parkingName}</strong> fue enviada correctamente.</p>` +
            `<p><strong>Número de solicitud:</strong> ${requestNumber}</p>` +
            `<p><strong>Parqueo:</strong> ${parkingName}</p>` +
            `<p>Nuestro equipo de soporte revisará tu información y se pondrá en contacto contigo para continuar el proceso.</p>` +
            `<p>Gracias por confiar en BeyGo.</p>` +
            `</div>`,
    });
});

// ─── Helper: get FCM token for a user ──────────────────────────────────────
async function getToken(uid) {
    if (!uid) return null;
    const snap = await db.collection("users").doc(uid).get();
    return snap.data()?.fcmToken ?? null;
}

// ─── Helper: send FCM notification ─────────────────────────────────────────
async function sendPush({ token, title, body, data = {} }) {
    if (!token) {
        console.log("⚠️  No FCM token, skipping push");
        return;
    }
    try {
        const res = await admin.messaging().send({
            token,
            notification: { title, body },
            data: { ...data },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
        });
        console.log("✅ FCM sent:", res);
    } catch (err) {
        console.error("❌ FCM error:", err.message);
    }
}

// ─── Reservation state machine notifications ────────────────────────────────
exports.onReservationChanged = onDocumentWritten(
    "reservations/{resId}",
    async (event) => {
        const before = event.data.before?.data() ?? {};
        const after = event.data.after?.data() ?? {};

        // Document deleted — ignore
        if (!event.data.after.exists) return;

        const userId = after.userId;
        const ownerId = after.ownerId;
        const parkingName = after.parkingName ?? "el parqueo";
        const spaceNumber = after.spaceNumber ?? "";
        const reservationNumber = after.reservationNumber ?? "";

        const stateBefore = before.state ?? "";
        const stateAfter = after.state ?? "";
        const approvalBefore = before.providerApprovalStatus ?? "";
        const approvalAfter = after.providerApprovalStatus ?? "";
        const exitBefore = before.exitStatus ?? "";
        const exitAfter = after.exitStatus ?? "";

        // ── 1. New reservation created → notify OWNER ─────────────────────────
        if (!event.data.before.exists && stateAfter === "pending") {
            const ownerToken = await getToken(ownerId);
            await sendPush({
                token: ownerToken,
                title: "🅿️ Nueva solicitud de reserva",
                body: `Espacio ${spaceNumber} en ${parkingName}`,
                data: {
                    route: "ownerReservations",
                    type: "new_reservation",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 2. Owner approves reservation → notify USER ───────────────────────
        if (
            approvalBefore !== "approved" &&
            approvalAfter === "approved" &&
            stateAfter === "active"
        ) {
            const userToken = await getToken(userId);
            await sendPush({
                token: userToken,
                title: "✅ ¡Reserva aprobada!",
                body: `Tu espacio ${spaceNumber} en ${parkingName} está listo`,
                data: {
                    route: "reservations",
                    type: "reservation_approved",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 3. Owner rejects reservation → notify USER ────────────────────────
        if (approvalBefore !== "rejected" && approvalAfter === "rejected") {
            const userToken = await getToken(userId);
            await sendPush({
                token: userToken,
                title: "❌ Reserva no aprobada",
                body: `Tu solicitud en ${parkingName} fue rechazada`,
                data: {
                    route: "reservations",
                    type: "reservation_rejected",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 4. User requests exit → notify OWNER ─────────────────────────────
        if (exitBefore !== "requested" && exitAfter === "requested") {
            const ownerToken = await getToken(ownerId);
            await sendPush({
                token: ownerToken,
                title: "🚗 Solicitud de salida",
                body: `Espacio ${spaceNumber} en ${parkingName} — No. ${reservationNumber}`,
                data: {
                    route: "ownerRequests",
                    type: "exit_requested",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 5. Owner confirms exit → notify USER ─────────────────────────────
        if (exitBefore !== "approved" && exitAfter === "approved") {
            const userToken = await getToken(userId);
            await sendPush({
                token: userToken,
                title: "✅ Salida aprobada",
                body: `Ya puedes finalizar tu reserva en ${parkingName}`,
                data: {
                    route: "reservations",
                    type: "exit_approved",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 6. User requests cancellation → notify OWNER ──────────────────────
        if (
            stateBefore !== "cancellation_requested" &&
            stateAfter === "cancellation_requested"
        ) {
            const ownerToken = await getToken(ownerId);
            await sendPush({
                token: ownerToken,
                title: "🔔 Solicitud de cancelación",
                body: `Espacio ${spaceNumber} en ${parkingName}`,
                data: {
                    route: "ownerRequests",
                    type: "cancel_requested",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 7. Reservation completed → notify USER ────────────────────────────
        if (stateBefore !== "completed" && stateAfter === "completed") {
            const amount = after.amount ?? after.estimatedAmount ?? 0;
            const userToken = await getToken(userId);
            await sendPush({
                token: userToken,
                title: "🎉 Reserva completada",
                body: `Monto: Q${amount} — ¡Gracias por usar ${parkingName}!`,
                data: {
                    route: "reservations",
                    type: "reservation_completed",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId,
                    spaceNumber: `${spaceNumber}`,
                },
            });
            return;
        }

        // ── 8. Cancellation confirmed by owner → notify USER ──────────────────
        if (
            stateBefore === "cancellation_requested" &&
            stateAfter === "cancelled" &&
            approvalAfter === "approved"
        ) {
            const userToken = await getToken(userId);
            await sendPush({
                token: userToken,
                title: "ℹ️ Cancelación procesada",
                body: `Tu reserva en ${parkingName} fue cancelada`,
                data: {
                    route: "reservations",
                    type: "cancellation_confirmed",
                    reservationId: event.params.resId,
                    reservationNumber,
                    parkingId: after.parkingId ?? "",
                    spaceNumber: `${spaceNumber}`,
                },
            });
        }
    }
);

exports.onReservationChatMessageCreated = onDocumentCreated(
    "reservations/{resId}/messages/{messageId}",
    async (event) => {
        const data = event.data?.data() ?? {};
        const reservationId = `${event.params.resId || ""}`.trim();
        if (!reservationId) return;

        const reservationSnap = await db
            .collection("reservations")
            .doc(reservationId)
            .get();

        if (!reservationSnap.exists) return;

        const reservation = reservationSnap.data() || {};
        const senderId = `${data.senderId || ""}`.trim();
        const senderRole = `${data.senderRole || ""}`.trim().toLowerCase();
        const text = `${data.text || ""}`.trim();

        if (!senderId || !text) return;

        const userId = `${reservation.userId || ""}`.trim();
        const ownerId = `${reservation.ownerId || ""}`.trim();
        const parkingName = `${reservation.parkingName || "tu reservación"}`.trim();
        const spaceNumber = `${reservation.spaceNumber || ""}`.trim();
        const reservationNumber = `${reservation.reservationNumber || ""}`.trim();
        const state = `${reservation.state || ""}`.trim().toLowerCase();

        if (!["pending", "active", "cancellation_requested"].includes(state)) {
            return;
        }

        const targetUserId = senderRole === "owner" ? userId : ownerId;
        if (!targetUserId) return;

        const token = await getToken(targetUserId);
        const senderLabel =
            senderRole === "owner"
                ? "El propietario"
                : `${reservation.userName || "El usuario"}`.trim();
        const preview =
            text.length > 110 ? `${text.slice(0, 107)}...` : text;

        await sendPush({
            token,
            title: `💬 Nuevo mensaje en ${parkingName}`,
            body: `${senderLabel}: ${preview}`,
            data: {
                route: senderRole === "owner" ? "reservations" : "ownerReservations",
                type: "chat_message",
                category: "chat",
                reservationId,
                reservationNumber,
                parkingId: `${reservation.parkingId || ""}`,
                spaceNumber,
                senderRole,
            },
        });
    }
);

exports.onParkingReviewWritten = onDocumentWritten(
    "parkings/{parkingId}/reviews/{reviewId}",
    async (event) => {
        const parkingId = `${event.params.parkingId || ""}`.trim();
        if (!parkingId) return;

        const parkingRef = db.collection("parkings").doc(parkingId);
        const reviewsSnap = await parkingRef.collection("reviews").get();

        const ratings = reviewsSnap.docs
            .map((doc) => Number(doc.data().rating || 0))
            .filter((rating) => Number.isFinite(rating) && rating > 0);

        const totalReviews = ratings.length;
        const rating =
            totalReviews > 0
                ? Number(
                    (ratings.reduce((sum, value) => sum + value, 0) / totalReviews)
                        .toFixed(1)
                )
                : 0;

        await parkingRef.set(
            {
                rating,
                totalReviews,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );
    }
);

// ─── package.json reminder ─────────────────────────────────────────────────
// {
//   "name": "functions",
//   "engines": { "node": "18" },
//   "main": "index.js",
//   "dependencies": {
//     "firebase-admin": "^12.0.0",
//     "firebase-functions": "^5.0.0"
//   }
// }
