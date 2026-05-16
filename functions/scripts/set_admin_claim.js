const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

function resolveProjectId() {
  const explicitProjectId =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID;

  if (explicitProjectId) {
    return explicitProjectId;
  }

  const firebaseRcPath = path.resolve(__dirname, "../../.firebaserc");
  if (!fs.existsSync(firebaseRcPath)) {
    return undefined;
  }

  const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, "utf8"));
  return firebaseRc?.projects?.default;
}

const projectId = resolveProjectId();

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

async function main() {
  const uid = process.argv[2];
  const rawAdminValue = process.argv[3] ?? "true";

  if (!uid) {
    console.error("Usage: npm run set-admin-claim -- <uid> [true|false]");
    process.exit(1);
  }

  const isAdmin = rawAdminValue.toLowerCase() === "true";
  const auth = admin.auth();
  const user = await auth.getUser(uid);
  const currentClaims = user.customClaims || {};
  const nextClaims = {
    ...currentClaims,
    admin: isAdmin,
  };

  if (!isAdmin) {
    delete nextClaims.admin;
  }

  await auth.setCustomUserClaims(uid, nextClaims);

  console.log(
    `Custom claims updated for ${uid}: ${JSON.stringify(nextClaims)}`
  );
  console.log(
    "Ask the user to sign out/in again so the fresh ID token includes the claim."
  );
}

main().catch((error) => {
  console.error("Failed to update custom claims:", error);
  process.exit(1);
});
