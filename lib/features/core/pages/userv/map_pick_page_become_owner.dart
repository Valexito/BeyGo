import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/widgets/map_picker_page.dart';

class MapPickPage extends StatelessWidget {
  final LatLng? initialPosition;

  const MapPickPage({super.key, this.initialPosition});

  @override
  Widget build(BuildContext context) {
    return MapPickerPage(
      title: 'Busca tu ubicacion',
      initialPosition: initialPosition,
    );
  }
}
