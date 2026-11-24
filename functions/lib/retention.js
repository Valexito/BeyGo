"use strict";

// Depuración automática de reservaciones según el plazo de conservación de la
// política de privacidad (24 meses). La lógica vive aquí, separada de la Cloud
// Function, para poder probarla con el emulador de Firestore (ver
// test_rules/package.json, script "test:depuracion").

const admin = require("firebase-admin");

const RESERVATION_RETENTION_MONTHS = 24;
// Solo se eliminan reservaciones terminadas; las activas o pendientes se conservan.
const PURGEABLE_STATES = ["completed", "cancelled", "manual_completed"];
const PURGE_PAGE_SIZE = 200;
const PURGE_MAX_PAGES = 50;

async function purgeExpiredReservations(db, {
    dryRun = true,
    now = new Date(),
    retentionMonths = RESERVATION_RETENTION_MONTHS,
    pageSize = PURGE_PAGE_SIZE,
    maxPages = PURGE_MAX_PAGES,
} = {}) {
    const cutoffDate = new Date(now.getTime());
    cutoffDate.setUTCMonth(cutoffDate.getUTCMonth() - retentionMonths);
    const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);

    let scanned = 0;
    let matched = 0;
    let deleted = 0;
    let failed = 0;
    let last = null;

    for (let page = 0; page < maxPages; page += 1) {
        let query = db
            .collection("reservations")
            .where("reservedAt", "<", cutoff)
            .orderBy("reservedAt")
            .limit(pageSize);
        if (last) query = query.startAfter(last);

        const snap = await query.get();
        if (snap.empty) break;
        last = snap.docs[snap.docs.length - 1];
        scanned += snap.size;

        for (const docSnap of snap.docs) {
            const state = `${docSnap.data()?.state || ""}`.trim().toLowerCase();
            if (!PURGEABLE_STATES.includes(state)) continue;
            matched += 1;
            if (dryRun) continue;
            try {
                await db.recursiveDelete(docSnap.ref);
                deleted += 1;
            } catch (error) {
                failed += 1;
                console.error(
                    `[retention-purge] Failed to delete reservation ${docSnap.id}:`,
                    error
                );
            }
        }
        if (snap.size < pageSize) break;
    }

    return { dryRun, cutoff: cutoffDate, scanned, matched, deleted, failed };
}

module.exports = {
    purgeExpiredReservations,
    RESERVATION_RETENTION_MONTHS,
    PURGEABLE_STATES,
};
