// Solo lectura: calcula la duración de las reservas completadas en Firestore.
// Uso (desde functions/):  gcloud auth application-default login
//                          node scripts/reservation_duration_stats.js [AAAA-MM-DD hasta]
const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: "beygo-app-prod" });

const until = process.argv[2] ? new Date(process.argv[2] + "T23:59:59-06:00") : null;
const toDate = (v) => (v && typeof v.toDate === "function" ? v.toDate() : null);
const stats = (a) => {
  if (!a.length) return "sin datos";
  const s = [...a].sort((x, y) => x - y), n = s.length;
  const q = (p) => { const i = (n - 1) * p, lo = Math.floor(i); return s[lo] + (s[Math.ceil(i)] - s[lo]) * (i - lo); };
  const mean = s.reduce((t, x) => t + x, 0) / n;
  return `n=${n} | media=${mean.toFixed(1)} h | mediana=${q(0.5).toFixed(1)} h | P25=${q(0.25).toFixed(1)} | P75=${q(0.75).toFixed(1)} | min=${s[0].toFixed(2)} | max=${s[n - 1].toFixed(1)}`;
};

(async () => {
  const snap = await admin.firestore().collection("reservations").get();
  const byState = {}, fromStamps = [], fromField = [];
  snap.forEach((d) => {
    const r = d.data(), st = r.state || "?";
    const start = toDate(r.reservedAt) || toDate(r.startedAt);
    if (until && start && start > until) return;
    byState[st] = (byState[st] || 0) + 1;
    if (st !== "completed") return;
    const end = toDate(r.endedAt);
    if (start && end) fromStamps.push((end - start) / 3.6e6);
    if (typeof r.durationMinutes === "number") fromField.push(r.durationMinutes / 60);
  });
  console.log("Reservas por estado:", byState);
  console.log("Duración (endedAt − reservedAt):          ", stats(fromStamps));
  console.log("  … excluyendo > 72 h:                    ", stats(fromStamps.filter((h) => h <= 72)));
  console.log("  … reservas > 72 h:", fromStamps.filter((h) => h > 72).length);
  console.log("Duración (campo durationMinutes):         ", stats(fromField));
  console.log("  … excluyendo > 72 h:                    ", stats(fromField.filter((h) => h <= 72)));
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
