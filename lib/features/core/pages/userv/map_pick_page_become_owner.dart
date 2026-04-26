import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:beygo/common/ui/widgets/map_picker_page.dart';

class MapPickPage extends StatelessWidget {
  const MapPickPage({super.key, this.initialPosition});

  final LatLng? initialPosition;

  @override
  Widget build(BuildContext context) {
    return MapPickerPage(
      title: 'Busca tu ubicacion',
      initialPosition: initialPosition,
    );
  }
}
