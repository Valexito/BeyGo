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
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
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
                data: { route: "ownerReservations", type: "new_reservation" },
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
                    reservationNumber,
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
                data: { route: "reservations", type: "reservation_rejected" },
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
                data: { route: "ownerRequests", type: "exit_requested" },
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
                    reservationNumber,
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
                data: { route: "ownerRequests", type: "cancel_requested" },
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
                    reservationNumber,
                    parkingId: after.parkingId,
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
                data: { route: "reservations", type: "cancellation_confirmed" },
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
