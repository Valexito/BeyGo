// lib/beygo.dart
// Barrel file global. Importa este archivo y obtienes acceso a TODA la app:
//
//   import 'package:beygo/beygo.dart';
//
// Recomendado solo para prototipos o tests rápidos. En código de producción
// prefiere los barrels por feature (`package:beygo/features/auth/auth.dart`)
// para mantener tree-shaking saludable y dependencias explícitas.
library;

export 'common/common.dart';
export 'features/auth/auth.dart';
export 'features/core/core.dart';
export 'features/owner/owner.dart';
export 'features/users/users.dart';
