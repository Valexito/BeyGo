# Pruebas de las reglas de seguridad de BeyGo

Pruebas automatizadas (emulador local de Firebase, proyecto ficticio `demo-beygo-rules`, **no tocan producción**) que intentan accesos indebidos entre roles contra `../firestore.rules` y `../storage.rules`.

## Requisitos
Node 18+ y Java 11+ (el emulador de Firestore/Storage corre sobre Java).

## Ejecutar
```bash
cd test_rules
npm install
npm run test:evidencia   # imprime el resultado y lo guarda en resultados_pruebas_reglas.txt
```

La primera vez, `firebase-tools` descarga los emuladores (necesita acceso a `storage.googleapis.com`).

## Identificadores
Cada bloque `describe` lleva el identificador del control de la matriz de la tesis (C04, C05, C06, C07, C12).
Roles simulados: sin sesión, usuario A, usuario B, proveedores 1 y 2 (rol `provider`) y administrador (claim `admin: true`).
