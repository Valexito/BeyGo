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
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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