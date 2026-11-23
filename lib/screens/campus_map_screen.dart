import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  static const LatLng _ubicacionCampus = LatLng(
    20.538880,
    -100.819381,
  );

  static const CameraPosition _posicionInicial = CameraPosition(
    target: _ubicacionCampus,
    zoom: 16,
  );

  GoogleMapController? _mapController;

  final Set<Marker> _marcadores = {
    const Marker(
      markerId: MarkerId('campus_itc'),
      position: _ubicacionCampus,
      infoWindow: InfoWindow(
        title: 'Instituto Tecnológico de Celaya',
        snippet: 'Campus I',
      ),
    ),
  };

  void _centrarCampus() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_posicionInicial),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del campus'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _posicionInicial,
            markers: _marcadores,
            mapType: MapType.normal,
            compassEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Instituto Tecnológico de Celaya',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Campus I · Celaya, Guanajuato',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Centrar en el campus',
                      onPressed: _centrarCampus,
                      icon: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
