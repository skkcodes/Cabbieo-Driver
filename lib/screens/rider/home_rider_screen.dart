

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';



import 'package:driver_cabbieo/global/global_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';



class HomeRiderScreen extends StatefulWidget {
  const HomeRiderScreen({super.key});

  @override
  State<HomeRiderScreen> createState() => _HomeRiderScreenState();
}

class _HomeRiderScreenState extends State<HomeRiderScreen> {
  final Completer<GoogleMapController> googleMapCompleterController =
      Completer<GoogleMapController>();
      Position? currentPositionOfUser;
      GoogleMapController? controllerGoogleMap;

      void updateMapTheme(GoogleMapController controller){
        getJsonFileFromThemes("themes/standard_style.json").then((value)=> setGoogleMapStyle(value,controller));
      }

    Future<String> getJsonFileFromThemes(String mapStylePath) async{
      ByteData byteData = await rootBundle.load(mapStylePath);
      var list = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      return utf8.decode(list);

    }

    setGoogleMapStyle(String googleMapStyle, GoogleMapController controller){
      controller.setMapStyle(googleMapStyle);

    }

    getCurrentLocationOfUser() async{
      Position positionOfUser = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      currentPositionOfUser=positionOfUser;

      LatLng positionOfUserInLatLng = LatLng(currentPositionOfUser!.latitude,currentPositionOfUser!.longitude);

      CameraPosition cameraPosition =CameraPosition(target: positionOfUserInLatLng, zoom: 15);
      controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
                  children: [
                    GoogleMap(
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      initialCameraPosition: googlePlexInitialPosition,
                      onMapCreated: (GoogleMapController mapController){
                        controllerGoogleMap = mapController;
                        updateMapTheme(controllerGoogleMap!);

                        googleMapCompleterController.complete(controllerGoogleMap);
                        getCurrentLocationOfUser();
                      },


                    ),
                    
                  ],
                )
    );
  }
}