// SOLO LECTURA. Exporta datos SIN información personal (sin nombres, correos, placas ni UIDs)
// para verificar y recalcular las cifras de la tesis.
// Uso, desde BeyGo/functions:
//   gcloud auth application-default login
//   node scripts/verificar_datos_tesis.js
// Resultado: carpeta BeyGo/datos_tesis/ (reservas.csv, cuentas.csv, resenas.csv, campos.txt)
const admin = require("firebase-admin");
const fs = require("fs"), path = require("path"), crypto = require("crypto");
admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: "beygo-app-prod" });
const db = admin.firestore();
const OUT = path.resolve(__dirname, "../../datos_tesis");
fs.mkdirSync(OUT, { recursive: true });

const anon = (s) => (s ? crypto.createHash("sha256").update(String(s)).digest("hex").slice(0, 10) : "");
const iso = (v) => (v && typeof v.toDate === "function" ? v.toDate().toISOString() : "");
const csv = (rows) => rows.map((r) => r.map((c) => {
  const s = c === undefined || c === null ? "" : String(c);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}).join(",")).join("\n") + "\n";
// Campos no personales que se exportan tal cual (además de todas las fechas y cualquier campo con "prod")
const SAFE = ["state", "providerApprovalStatus", "exitStatus", "durationMinutes", "estimatedDurationMinutes",
  "pricePerHour", "amount", "estimatedAmount", "spaceNumber", "cancelledBy", "ratingSubmitted",
  "cancellationPenaltyApplied", "reservationNumber"];

(async () => {
  // Reservas
  const snap = await db.collection("reservations").get();
  const tsKeys = new Set(), prodKeys = new Set(), allKeys = {};
  snap.forEach((d) => Object.entries(d.data()).forEach(([k, v]) => {
    allKeys[k] = (allKeys[k] || 0) + 1;
    if (v && typeof v.toDate === "function") tsKeys.add(k);
    if (/prod/i.test(k) || (typeof v === "string" && /prod/i.test(v))) prodKeys.add(k);
  }));
  const ts = [...tsKeys].sort(), pk = [...prodKeys].sort();
  const head = ["id", "parking", "user", "owner", ...SAFE, ...pk.filter((k) => !SAFE.includes(k)), ...ts];
  const rows = [head];
  snap.forEach((d) => {
    const r = d.data();
    rows.push(head.map((h) => h === "id" ? anon(d.id) : h === "parking" ? anon(r.parkingId)
      : h === "user" ? anon(r.userId) : h === "owner" ? anon(r.ownerId || r.ownerID)
      : ts.includes(h) ? iso(r[h]) : (typeof r[h] === "object" && r[h] !== null ? JSON.stringify(r[h]) : r[h])));
  });
  fs.writeFileSync(path.join(OUT, "reservas.csv"), csv(rows));

  // Cuentas (solo fecha de creación y si tiene documento de usuario)
  let users = [], tok;
  do { const r = await admin.auth().listUsers(1000, tok); users.push(...r.users); tok = r.pageToken; } while (tok);
  const udocs = new Set((await db.collection("users").select().get()).docs.map((d) => d.id));
  fs.writeFileSync(path.join(OUT, "cuentas.csv"), csv([["user", "creada", "ultimo_acceso", "doc_users", "admin"],
    ...users.map((u) => [anon(u.uid), new Date(u.metadata.creationTime).toISOString(),
      u.metadata.lastSignInTime ? new Date(u.metadata.lastSignInTime).toISOString() : "",
      udocs.has(u.uid) ? 1 : 0, u.customClaims?.admin ? 1 : 0])]));

  // Reseñas y parqueos
  const rv = await db.collectionGroup("reviews").get();
  fs.writeFileSync(path.join(OUT, "resenas.csv"), csv([["parking", "rating", "fecha"],
    ...rv.docs.map((d) => [anon(d.ref.parent.parent?.id), d.data().rating,
      iso(d.data().createdAt) || iso(d.data().updatedAt) || iso(d.updateTime)])]));
  const pks = await db.collection("parkings").get();

  fs.writeFileSync(path.join(OUT, "campos.txt"),
    `Generado: ${new Date().toISOString()}\nReservas: ${snap.size}\nCuentas Auth: ${users.length} | docs users: ${udocs.size}\n` +
    `Reseñas: ${rv.size}\nParqueos: ${pks.size} -> ${pks.docs.map((d) => `${anon(d.id)} rating=${d.data().rating} totalReviews=${d.data().totalReviews} activo=${d.data().isActive ?? d.data().active ?? "?"}`).join(" | ")}\n` +
    `Campos con "prod": ${pk.join(", ") || "(ninguno)"}\nCampos de fecha: ${ts.join(", ")}\n` +
    `Frecuencia de campos en reservas:\n${Object.entries(allKeys).sort().map(([k, n]) => `  ${k}: ${n}`).join("\n")}\n`);
  console.log("Listo. Archivos en", OUT);
  process.exit(0);
})().catch((e) => { console.error("ERROR:", e.message); process.exit(1); });
