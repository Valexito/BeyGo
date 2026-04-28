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
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

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

async function sendMailSafe({ to, subject, text, html }) {
    if (!to) return;
    const transport = getMailTransport();
    await transport.sendMail({
        from: ownerSecurityEmail.value(),
        to,
        subject,
        text,
        html,
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
    const email = userSnap.data()?.email;

    if (!email) {
        throw new HttpsError(
            "failed-precondition",
            "No se encontró un correo válido para este owner."
        );
    }

    return { email };
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
            `Tu solicitud para convertirte en owner fue enviada correctamente.\n\n` +
            `Número de solicitud: ${requestNumber}\n` +
            `Parqueo: ${parkingName}\n\n` +
            `Nuestro equipo de soporte revisará tu información y se pondrá en contacto contigo para continuar el proceso.\n\n` +
            `Gracias por confiar en BeyGo.`,
        html:
            `<div style="font-family:Arial,sans-serif;padding:16px">` +
            `<h2>Solicitud recibida</h2>` +
            `<p>Tu solicitud para convertirte en <strong>owner</strong> fue enviada correctamente.</p>` +
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
