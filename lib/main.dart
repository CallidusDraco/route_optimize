
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' ;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoder/geocoder.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import "package:google_maps_webservice/places.dart";
import 'package:google_maps_webservice/directions.dart' as DM;
import 'package:google_maps_webservice/geolocation.dart';
import 'package:latlong/latlong.dart' as OP;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'dart:async';

import 'userLocationPermission.dart';
import 'Device_ID.dart';
import 'Restaurants.dart';


import 'package:location/location.dart' as LM;


final databaseReference = FirebaseDatabase.instance.reference();



const kGoogleApiKey = "AIzaSyAtkORU-7NcIIy-zd8cVPRSP8BdNhDofE4";
DM.GoogleMapsDirections direct = DM.GoogleMapsDirections(
    apiKey: kGoogleApiKey
);
PlacesSearchResponse global;

String fromAdres = "From";
String toAdres = "To";
String userChoice ="";
List <String> selectOrder = new List();
String device_ID = "";
String journey_Key = "";
bool resAlr, haveKey = false;

List <DM.Waypoint> usrSelections  = new List();
List <Widget> waypoints = new List();

GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

Timer endJour, upTime;
var a;
var b;
//Set<Marker> markers = Set();


void main() {

  runApp(MaterialApp(


    initialRoute: 'init',
    routes: <String, WidgetBuilder>{
      'init': (context) => usrLocPermit(),
      'home': (context) => MyHomePage(),

    },
  ));
}


void createRecord(String deviceID, List <LatLng> coor, String arrived, String restaurantName,
                  List<String> resNames, double distance, bool Fin, OP.LatLng usr_Loc ){

  var newInfo = databaseReference.child(deviceID + "/Journey Log").child(journey_Key);
  DateTime now = DateTime.now();
  String timeStamp = DateFormat('kk:mm:ss EEE d MMM').format(now);
  /* TEMPLATE
     newInfo.set({

        'Starting point': {
          'latitude': a.lat,
          'longitude': a.lng
        },
        'Destination': {
          'latitude': b.lat,
          'longitude': b.lng
        },

        'Algorithm': "None",
        'Coordinates': "None",
        'Arrived': "No",
        'Number of routes recommended': "None",
        "Recommended places names": "None",
        'User selected place': "None",
        'Distance to end point': "None",
        'User Location': {
          'latitude': usr_Loc.latitude,
          'longitude': usr_Loc.longitude
        },
        "Journey finished": false
      });
      TEMPLATE
     */
  newInfo.child("Coordinates").set("List of coordinates");
  newInfo.child("Arrived").set(arrived);
  newInfo.child("Recommended places names").set(resNames);
  newInfo.child("User selected place").set(restaurantName);
  newInfo.child('Distance to end point').set(distance);
  newInfo.child("Journey finished").set(Fin);
  newInfo.child("User Location").child(timeStamp).child('latitude').set(usr_Loc.latitude);
  newInfo.child("User Location").child(timeStamp).child('longitude').set(usr_Loc.longitude);

}

List <double> checkDistance(OP.LatLng usrLocation, String restaurantName){
  OP.Distance distance = new OP.Distance();
  List <double> meter = [0.0 ,0.0]; // 0: restaurant distance , 1: distance to destination

  for(int i =0; i < resNames.length; i++ ){
    if(restaurantName == resNames[i]) {
      meter[0] = distance(usrLocation, OP.LatLng(food_points[i].latitude, food_points[i].longitude));
    }
  }
  meter[1] = distance(usrLocation, OP.LatLng(b.lat, b.lng));
  return meter;


}

bool JourneyFinished (double distance){
  if(distance > 0 && distance <= 50){
    var newInfo = databaseReference.child(device_ID + "/Journey Log").child(journey_Key);
    newInfo.child("Arrived").set("No");
    newInfo.child("Journey finished").set(true);
    endJour.cancel();
    upTime.cancel();
    food_points.clear();
    resNames.clear();
    usrSelections.clear();
    resAlr = false;
    return true;
  }else { return false;}
}

String UserArrived(double distance){
  if(distance <= 100 && distance > 0){
    return "Yes";
  }
  else {
    return "No";
  }
}

Future<void> updateUsrLoc()async {
  GeolocationResponse res_Two;
  final geolocation = new GoogleMapsGeolocation(apiKey: kGoogleApiKey);

  OP.LatLng usr_Loc;

  res_Two = await geolocation.currentGeolocation();

  //print(res.status);

  if (res_Two.isOkay) {
    usr_Loc = new OP.LatLng(res_Two.location.lat, res_Two.location.lng);
    List <double> distance = checkDistance(usr_Loc, userChoice);
    createRecord(device_ID ,food_points, UserArrived(distance[0]), userChoice, resNames,
                  distance[0], JourneyFinished(distance[1]), usr_Loc );

  }

}

class MyHomePage extends StatefulWidget {

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  StreamSubscription<Event> _onJourneyParamChanged;
  //**********************Initialize Google Map Controller **********************
  double  fromLat, fromLng, toLat, toLng = null;
  String FromID, ToID;
  final geolocation = new GoogleMapsGeolocation(apiKey: kGoogleApiKey);
  DM.DirectionsResponse route;
  GeolocationResponse res;
  GoogleMapController mapController;
  Position currentLocation;
  //add more markers to this by using markers.add(Marker object);

  Set<Marker> markers = {}  ;
  var midpoint;

  List <DM.Waypoint> resChoice = new List();
  //final Set<Marker> restaurants = {};
  final Set<Polyline> polyline={};
  final List<LatLng> points = List();
  final List<LatLng> usr_points = List();
  final List<LatLng> midPoints = List();
  final LatLng _center = const LatLng(1.341817, 103.961932);

  void initState(){

    drawDeviceID().then((id){
      device_ID =id;

      //print("My device ID is: " + device_ID);

    });


    for (int i = 0; i < 2; i++){
      usr_points.add(LatLng(0, 0));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }



  //**********************Initialize Google Map Controller **********************

  //**********************Text Editing Controller for Search bars**********************


  String fromChange = "From ";
  String toChange = "From ";

  String title_text = 'Hi Human';
  bool haveFrom = false;
  bool haveTo = false;
  bool fromEnable = true;
  bool toEnable = true;
  bool text_visible = true;
  bool dining_visible = true;
  bool scene_visible = true;
  bool walking_visible = true;
  bool buildInfo = false;
  bool buildIter = false;

  //**********************Text Editing Controller for Search bars**********************



  //*************************** ADD MARKERS FUNCTIONS ***********************************

  void _AddFromMarker(double lan, double lon){
    final MarkerId fromId = MarkerId("From");
    Marker marker = Marker(
      onTap: (){
        //PlaceDetailWidget(FromID);
        //print("From Tap is working");
      },
      markerId: fromId,
      position: LatLng(lan, lon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
    setState((){
      if(markers != null) {

        markers.removeWhere((item) => item.markerId == MarkerId("From"));
        markers.removeWhere((item) => item.markerId == MarkerId("curr_loc"));
       // markers.remove("MyLoc");


      }
      markers.add(marker);
      //print(markers.length);
    });
  }

  void _AddToMarker(double lan, double lon){
    final MarkerId toId = MarkerId("To");
    Marker marker = Marker(
      onTap: (){
        //PlaceDetailWidget(ToID);
        //print("To Tap is working");
      },
      markerId: toId,
      position: LatLng(lan, lon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    setState((){
      if(markers != null ){

        markers.removeWhere((item) => item.markerId== MarkerId("To"));

      }
      markers.add(marker);

    });
  }

  void _AddRoute(){
    final PolylineId routeId = PolylineId("MR");
    Polyline poly = Polyline(

      polylineId: routeId,
      visible: true,
      points: points,
      width: 5,
      color: Colors.blue
    );
    setState((){
      if(polyline  != null ){
        polyline.remove("MR");
      }
      polyline.add(poly);
    });
  }


  //*************************** ADD MARKERS FUNCTIONS ***********************************

  //***************************FUNCTIONS FOR BUTTONS***********************************

  //DINING BUTTON FUNCTIONS
  void dining(){ //DINING BUTTON FUNCTIONS
    setState((){

      dining_visible = true;
      scene_visible = false;
      walking_visible = false;
      title_text = "Food nearby";
      text_visible = false;
      food_points.clear();
      restaurants.clear();
      resNames.clear();
      fromEnable = false;
      toEnable = false;
      if(haveFrom && haveTo ){
         requestRecommendation("Dining");
      }

    });
  }

  //SCENIC BUTTON FUNCTIONS
  void scenic(){
    setState(() {
      dining_visible = false;
      scene_visible = true;
      walking_visible = false;
      title_text = "Scenic";
      text_visible = false;
      food_points.clear();
      restaurants.clear();
      resNames.clear();
      fromEnable = false;
      toEnable = false;
      if(haveFrom && haveTo ){
        requestRecommendation("Scenic");
      }
    });
  }

  //WALKING BUTTON FUNCTIONS
  void walking(){
    setState(() {
      dining_visible = false;
      scene_visible = false;
      walking_visible = true;
      title_text = "Walking";
      text_visible = false;
      food_points.clear();
      restaurants.clear();
      resNames.clear();
      fromEnable = false;
      toEnable = false;
      if(haveFrom && haveTo ){
        requestRecommendation("Walking");
      }
    });
  }

  //CREATE RESTAURANT INFO CARD WHEN CARD IS PRESSED
  void res_Selected(){
    setState(() {
      buildInfo = true;
    });
  }

  //***************************FUNCTIONS FOR BUTTONS***********************************


  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.grey[300],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: AppBar(
          centerTitle: true,
          elevation: 0.0,
          title:
          Align(
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: Duration(milliseconds: 200),
              child: Text(
                  title_text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,

                  )
              ),
            ),
          ),
          backgroundColor: Colors.red,
        ),
      ),
      body:

      Column(
        children: <Widget>[

          //*******************************MAIN DISPLAY CONTAINER*******************************

          Expanded(
            flex: 9,
            child: Container(

              color: Colors.cyan,
              child:Stack(
                alignment: Alignment.center,
                children: <Widget>[

                  //********************************GOOGLE MAP DISPLAY****************************

                  GoogleMap(
                    polylines: polyline,
                    onMapCreated: _onMapCreated,
                    zoomGesturesEnabled: true,
                    mapToolbarEnabled: true,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 11.0,

                    ),
                    markers: markers,

                  ),

                  //********************************GOOGLE MAP DISPLAY****************************


                  UI(buildInfo), //MAIN UI COMPONENT


                  //*****************YOUR POSITION BUTTON****************

                  Align(

                      alignment: Alignment.topRight,
                      child: FloatingActionButton(
                        heroTag: "My location",
                        onPressed: () {

                          _getLocation();

                        },
                        mini: true,
                        child: Image.asset('asset/gps.png'),
                        backgroundColor: Colors.white,
                      )
                  ),


                  //*****************YOUR POSITION BUTTON****************

                ],
              ),
            ),
          ),

          //*******************************MAIN DISPLAY CONTAINER AREA*******************************


          //*********************NAVIGATION CONTAINER AREA*********************

          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,

              //***************************Navigation buttons**************************

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[

                  SizedBox(
                    height: 48,
                    width: 48,
                    child: FlatButton(
                        onPressed: (){
                          setState(() {
                            text_visible = true;
                            dining_visible = true;
                            scene_visible =  true;
                            walking_visible = true;
                            fromEnable = true;
                            toEnable = true;
                            buildInfo = false;
                          });
                        },
                        child: Image.asset("asset/home.png")
                    ),
                  ), //home button

                ],
              ),

              //***************************Navigation buttons**************************

            ),
          ),

          //*********************NAVIGATION CONTAINER AREA*********************

        ],
      ),

    );
  }

  Widget UI(bool Info){

    if(!Info){
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[

          ToTextBox(),
          FromTextBox(),
          RouteChangeButtons()
        ],
      );
    }
    if(Info){

      return Stack(alignment: Alignment.center,
        children: <Widget>[
          Itinerary(),
          buildInfoContainer()
        ],
      );
    }
  }

  Widget RouteChangeButtons(){

      return Positioned(
        top: 440,
        child: Container(
          //padding: EdgeInsets.all(15),
          // margin: EdgeInsets.only(top: 15, left: 50, right:55),
          width: 311,
          height: 98,
          //margin: EdgeInsets.only(top: 15),
          color: Colors.white,
          child: Row(
            //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            //crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[

              //****************DINING BUTTON****************

              AnimatedOpacity(
                opacity: dining_visible ? 1.0 : 0.2,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton(
                  heroTag: "dining",
                  onPressed: dining,
                  backgroundColor: Color(0xff5CBAF7),
                  child: Image.asset('asset/dining.png'),
                ),
              ),

              //****************DINING BUTTON****************


              //****************SCENIC BUTTON****************
              AnimatedOpacity(
                opacity: scene_visible ? 1.0 : 0.2,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton(
                  heroTag: "scenic",
                  onPressed: scenic,
                  backgroundColor: Color(0xff27DD45),
                  child: Image.asset('asset/tree.png'),
                ),
              ),

              //****************SCENIC BUTTON****************


              //****************WALKING BUTTON****************

              AnimatedOpacity(
                opacity: walking_visible ? 1.0 : 0.2,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton(
                  heroTag: "walking",
                  backgroundColor: Color(0xffF35C50),
                  onPressed: walking,
                  child: Image.asset('asset/walking.png'),
                ),
              ),

              //****************WALKING BUTTON****************

            ],
          ),
        ),
      );

  }

  //"To" text box
  Widget ToTextBox(){

      return Positioned(
        top: 385,
        child: AnimatedOpacity(
          opacity: text_visible ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Container(
              width: 311,
              height: 45,
              //margin: EdgeInsets.only(top: 15,left: 50, right:50),
              padding: EdgeInsets.only(left: 15, right: 15),
              color: Colors.white,
              child: Row(
                children: <Widget>[
                  Image.asset("asset/search.png"),
                  //Text(" To", style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: FlatButton(


                      onPressed: () {
                        setState(() async{
                          if (toEnable) {
                            // show input autocomplete with selected mode
                            // then get the Prediction selected
                            Prediction t = await PlacesAutocomplete
                                .show(
                                context: context,
                                apiKey: kGoogleApiKey);
                            ToPrediction(t);
                            toAdres = t.description;

                          }


                        });

                      },
                      child: new Text(toAdres, softWrap: true,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),

                  ),
                ],
              )
          ),
        ),
      );

  }

  //Used with "To" text box to predict place from keywords
  Future<Null> ToPrediction (Prediction t) async {
    if (t!= null) {
      PlacesDetailsResponse detail =
      await _places.getDetailsByPlaceId(t.placeId);
      //var placeId = t.placeId;
      ToID = t.placeId;
      //print(ToID);
      double lat = detail.result.geometry.location.lat;
      double lng = detail.result.geometry.location.lng;
      _AddToMarker(lat, lng);
      b = Location(lat,lng);
      //b = detail.result.geometry.location;

      //LocationManager myLoc;
      toLat = lat; toLng = lng;
      usr_points[1] = LatLng(lat, lng);
      haveTo = true;
      if(haveTo && haveFrom && haveKey){
        _onJourneyParamChanged.cancel();
        //usrSelections.clear();
        markers = markers.difference(restaurants);
        //var newInfo = databaseReference.child(device_ID + "/Journey Log").child(journey_Key);
        //newInfo.child("Journey finished").set(true);
        endTrack();
      }

      mapController.animateCamera(
          CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: LatLng(lat,lng),
                  zoom: 15.0)
          )
      );

      getDirectForUsr();
      //await requestRecommendation();


    }else {usr_points[1] = LatLng(0,0); haveFrom = false;}
  }

  //Used with "From" text box to predict place from keywords
  Widget FromTextBox(){
      return Positioned(
        top: 330,
        child: AnimatedOpacity(
          opacity: text_visible ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Container(
            //margin: EdgeInsets.only(top: 10, left: 50, right:50),
            width: 311,
            height: 45,
            //margin: EdgeInsets.only(top: 15),
            padding: EdgeInsets.only(left: 15, right: 15),
            color: Colors.white,
            child: Row(
              children: <Widget>[
                Image.asset("asset/search.png"),
                //Text(" From",style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  //minWidth: 250,
                  child: FlatButton(
                    onPressed: ()  {
                      setState(() async{
                        if (fromEnable) {
                          // show input autocomplete with selected mode
                          // then get the Prediction selected
                          Prediction f = await PlacesAutocomplete
                              .show(
                              context: context,
                              apiKey: kGoogleApiKey);
                          FromPrediction(f);
                          fromAdres = f.description;
                          //_onAddMarkerButtonPressed();

                        }

                      });

                    },
                    child: new Text(fromAdres, softWrap: true,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                ),
              ],
            ),
          ),
        ),
      );

  }

  //Used with "From" text box to predict place from keywords
  Future<Null> FromPrediction(Prediction f) async {
    if (f != null) {
      PlacesDetailsResponse detail =
      await _places.getDetailsByPlaceId(f.placeId);
      FromID = f.placeId;
      //print(FromID);
      //var placeId = f.placeId;
      double lat = detail.result.geometry.location.lat;
      double lng = detail.result.geometry.location.lng;
      a = Location(lat,lng);

      //a = detail.result.geometry.location;

      // print("Testing setters: " + lat.toString() + "   " + lng.toString());
      _AddFromMarker(lat, lng);
      //LocationManager myLoc;
      fromLat = lat; fromLng = lng;


      //usr_points[0] = null;
      usr_points[0] = LatLng(lat, lng);
      haveFrom = true;
      if(haveTo && haveFrom && haveKey){
        _onJourneyParamChanged.cancel();
        markers = markers.difference(restaurants);

        endTrack();
        haveKey = false;
      }



      //myLoc.setFromLat(lat); myLoc.setFromLng(lng);

      mapController.animateCamera(
          CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: LatLng(lat,lng),
                  zoom: 15.0)
          )
      );
      getDirectForUsr();
      //await requestRecommendation();

    }else {usr_points[0] = LatLng(0,0); haveFrom = false;}
  }

  Widget buildInfoContainer()  {
    List<Widget> boxInfo = new List();
   // PlacesDetailsResponse rep;
    var photoRef ;
    for(int i = 0; i < resNames.length; i++){
      //getPlaceID(resNames[i]).then((value){
       // rep = value;
        //print(rep.result.photos[0].photoReference);
        //photoRef = rep.results[0].photos;

        //buildPhotoURL(rep.results[0].photos[0].photoReference);
        //print(photoRef.toString());

      //});
      boxInfo.add(
          SizedBox(width: 10.0)
      );
      boxInfo.add (
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:_boxes(  "https://lh5.googleusercontent.com/p/AF1QipN-z-Qt3AouGu4itJjwSfiixG9gTmX2gWRyQwe6=w408-h306-k-no",
              food_points[i].latitude, food_points[i].longitude, resNames[i]),
        ),
      );
    }
    //print(boxInfo.length);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 20.0),
        height: 150.0,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: boxInfo,
        ),
      ),
    );

  }

  Widget _boxes(String _image, double lat,double long,String restaurantName) {
    return  GestureDetector(
      onTap: () {
        //_gotoLocation(lat, long);
       // userChoice = restaurantName;
        //resChoice[0] = usrSelections[resNames.indexOf(userChoice)];
        //getDirectForUsr();
      },
      child:Container(

        child: new FittedBox(
          child: Material(
              color: Colors.white,
              elevation: 14.0,
              borderRadius: BorderRadius.circular(24.0),
              shadowColor: Color(0x802196F3),
              child: Stack(
                children: <Widget>[

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[

                      Container(
                        width: 180,
                        height: 200,
                        child: ClipRRect(
                          borderRadius: new BorderRadius.circular(24.0),
                          child: Image(
                            fit: BoxFit.fill,
                            image: NetworkImage(_image),
                          ),
                        ),),

                      Container(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: myDetailsContainer1(restaurantName),
                        ),
                      ),

                    ],),

                  Positioned(
                    top: 5,
                    right: 5,
                    child: AddBtn(restaurantName),
                  ),



                ],
              ),

          ),
        ),
      ),
    );
  }

  Widget Itinerary(){

    if(resNames.contains(userChoice)) {
      return Positioned(
          top: 265,

          child: Container(
            height: 100,
            margin: EdgeInsets.symmetric(vertical: 10.0),
            child: Material(
                color: Colors.white,
                //elevation: 14.0,
                borderRadius: BorderRadius.circular(24.0),
                shadowColor: Color(0x802196F3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 5.0),
                      child: Container(
                        child: Text(
                          "Travel Iternary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 20.0,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 380,
                      margin: EdgeInsets.symmetric(vertical: 5.0),
                      child: new ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: waypoints.length,
                        itemBuilder: (context, index) {
                          return waypoints[index];
                        },
                      )
                    )
                  ],
                )

            ),

          )

      );

    }
    else {
      return Positioned(
          top: 265,

          child: Container(
            height: 100,
            margin: EdgeInsets.symmetric(vertical: 10.0),
            child: Material(
                color: Colors.white,
                //elevation: 14.0,
                borderRadius: BorderRadius.circular(24.0),
                shadowColor: Color(0x802196F3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 5.0),
                      child: Container(
                        child: Text(
                          "Travel Iternary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 20.0,
                          ),
                        ),
                      ),
                    ),
                    Container(
                        height: 40,
                        width: 380,
                        margin: EdgeInsets.symmetric(vertical: 5.0),
                        child: new ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: waypoints.length,
                          itemBuilder: (context, index) {
                            return waypoints[index];
                          },
                        )
                    )
                  ],
                )

            ),

          )

      );
    }


  }
  
  Widget RemoveBtn(String choice){
    return GestureDetector(
      onTap: (){
        setState(() {
          waypoints.removeAt(selectOrder.indexOf(choice));
          selectOrder.remove(choice);
          resChoice.remove(usrSelections[resNames.indexOf(choice)]);
          //resChoice.removeAt(a);
          //waypoints.
          //waypoints.removeAt(a);
          //getDirectForUsr();
          getDirectForUsr();

        });

        //print(waypoints.length);
      },
      child:Container(
        padding: const EdgeInsets.all(5.0),
        margin: EdgeInsets.all(2.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(
                color: Color(0xff73C3F7),
                width: 2.0
            )
        ),
        child: new FittedBox(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                userChoice,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xff73C3F7),
                  fontSize: 12.0,
                ),
              ),

              Container(
                  child: Image.asset("asset/X.png")
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget AddBtn(String restaurantName){
    return GestureDetector(
      onTap: (){
        setState(() {
          userChoice = restaurantName;
          if (!resChoice.contains(usrSelections[resNames.indexOf(userChoice)])){
            selectOrder.add(userChoice);
            resChoice.add(usrSelections[resNames.indexOf(userChoice)]);
            waypoints.add(RemoveBtn(userChoice));

          }


          //print(resChoice.length);
          getDirectForUsr();
        });


      },
      child: Container(
        padding: const EdgeInsets.all(5.0),
        margin: EdgeInsets.all(2.0),
        alignment: Alignment.center,
        width: 100,
        height: 35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(
              color: Colors.red,
              width: 2.0
          )
        ),
        child: Text(
          "Add",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
            fontSize: 18.0,
          ),
        ),
      ),
    );
  }

  Widget myDetailsContainer1(String restaurantName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Container(
              child: Text(restaurantName,
                style: TextStyle(
                    color: Color(0xff6200ee),
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold),
              )),
        ),
        SizedBox(height:5.0),
        Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Container(
                    child: Text(
                      "4.1",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 18.0,
                      ),
                    )),
                Container(
                  child: Icon(
                    FontAwesomeIcons.solidStar,
                    color: Colors.amber,
                    size: 15.0,
                  ),
                ),
                Container(
                  child: Icon(
                    FontAwesomeIcons.solidStar,
                    color: Colors.amber,
                    size: 15.0,
                  ),
                ),
                Container(
                  child: Icon(
                    FontAwesomeIcons.solidStar,
                    color: Colors.amber,
                    size: 15.0,
                  ),
                ),
                Container(
                  child: Icon(
                    FontAwesomeIcons.solidStar,
                    color: Colors.amber,
                    size: 15.0,
                  ),
                ),
                Container(
                  child: Icon(
                    FontAwesomeIcons.solidStarHalf,
                    color: Colors.amber,
                    size: 15.0,
                  ),
                ),
                Container(
                    child: Text(
                      "(946)",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 18.0,
                      ),
                    )),
              ],
            )),
        SizedBox(height:5.0),
        Container(
            child: Text(
              "American \u00B7 \u0024\u0024 \u00B7 1.6 mi",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 18.0,
              ),
            )),
        SizedBox(height:5.0),
        Container(
            child: Text(
              "Closed \u00B7 Opens 17:00 Thu",
              style: TextStyle(
                  color: Colors.black54,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold),
            )),
      ],
    );
  }



  /*
  Future<void> _gotoLocation(double lat,double long) async {

    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, long), zoom: 15,tilt: 50.0,
      bearing: 45.0,)));
  }
  */




  Future <void> requestRecommendation(String mode)async{

    var currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);


    if(haveFrom && haveTo) {

        var newInfo = databaseReference.child(device_ID + "/Journey Log")
            .push();
        journey_Key = newInfo.key;
        haveKey = true;
        //usr_Loc = new OP.LatLng(res_Two.location.lat, res_Two.location.lng);
        DateTime now = DateTime.now();
        String timeStamp = DateFormat('kk:mm:ss EEE d MMM').format(now);
        newInfo.set({

          'Starting point': {
            'latitude': a.lat,
            'longitude': a.lng
          },
          'Destination': {
            'latitude': b.lat,
            'longitude': b.lng
          },

          'Algorithm': "None",
          'Coordinates': {
            'latitude': "None",
            'longitude': "None"
          },
          'Arrived': "Null",
          //'Tag': mode, // Scenic, Walking,Dining
          'Number of routes recommended': "None",
          "Recommeded places names": "None",
          'User selected place': "None",
          'Distance to end point': "None",
          "Journey finished": false
        });
        newInfo.child("User Location").child(timeStamp).child("latitude").set(
            currentLocation.latitude);
        newInfo.child("User Location").child(timeStamp).child("longitude").set(
            currentLocation.longitude);

        pullRec(newInfo);

    }
  }

  //Start a new journey end track it
  void jourTracking() async{
    //_onJourneyParamChanged.cancel();
    const timeout = const Duration(hours: 2);
    const onGoing = const Duration(minutes: 10);
    endJour = new Timer.periodic(timeout, (Timer e) => endTrack());
    upTime = new Timer.periodic(onGoing, (Timer t) => updateUsrLoc());
    resAlr = true;

  }

  //End a journey, stop tracking journey
  void endTrack(){
    var newInfo = databaseReference.child(device_ID + "/Journey Log").child(journey_Key);
    newInfo.child("Arrived").set("No");
    newInfo.child("Journey finished").set(true);
    endJour.cancel();
    upTime.cancel();
    food_points.clear();
    resNames.clear();
    usrSelections.clear();
    resAlr = false;

  }

  //Start a listener for device
  void pullRec(DatabaseReference journeyRef){

    _onJourneyParamChanged = journeyRef.child('Coordinates').onValue.listen(onData);

  }

  //Used with pullRec
  void onData(Event event) async {
    var temp =  event.snapshot.value;
    //print(temp["latitude"]);
    if(temp["latitude"] != "None" && temp["longitude"] != "None") {
      for (int i = 0; i < temp["latitude"].length; i++) {
        food_points.add(LatLng(temp["latitude"][i], temp["longitude"][i]));
        await getAddress(temp["latitude"][i], temp["longitude"][i]).then((value) {
          resNames.add(value);
        });
        //print(resNames[i]);
        //print(food_points[i].latitude);
        //print(food_points[i].longitude);
        DM.Location d = new DM.Location(food_points[i].latitude, food_points[i].longitude);
        DM.Waypoint asd = new DM.Waypoint(d.toString());
        usrSelections.add(asd);

      }
      await addResMarker();
      jourTracking();
    }


    //_onJourneyParamChanged.cancel();
  }

  //Add restaurants markers
  Future <void> addResMarker() async{
    for(int i = 0; i < resNames.length; i++){
      final MarkerId fromId = MarkerId(resNames[i]);

      Marker marker = Marker(
        onTap: (){
          res_Selected();

          //PlaceDetailWidget(FromID);
          //print("From Tap is working");
        },
        markerId: fromId,
        position: food_points[i],
        infoWindow: InfoWindow(title: resNames[i]),
        icon: BitmapDescriptor.defaultMarkerWithHue(204),
      );
      setState((){
        restaurants.add(marker);

      });


    }
    setState((){
      markers = markers.union(restaurants);


    });


  }


  Future <PlacesDetailsResponse> getPlaceID(String address) async{
    final places = new GoogleMapsPlaces(apiKey: kGoogleApiKey);
    PlacesSearchResponse rep= await places.searchByText(address);
    PlacesDetailsResponse trueRep = await places.getDetailsByPlaceId(rep.results[0].placeId) ;
    return trueRep;
  }

  /*
  String buildPhotoURL(String photoReference) {
    return "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photoReference}&key=${kGoogleApiKey}";
  }
  */

  //Get direction based on given coordinates (starting position, destination and waypoints)
  Future <void> getDirectForUsr() async {
    //print("I'm have from: " + haveTo.toString());
    //print(haveFrom);
    if(haveTo && haveFrom) {

      if(usrSelections.length > 0 ) {
        route = await direct.directions(a, b, waypoints: resChoice);
      }
      else{
        route = await direct.directions(a, b);
      }
      points.clear();


      PolylinePoints trueDmg = new PolylinePoints();

      if (route.isOkay) {
        List <PointLatLng> trueWay = trueDmg.decodePolyline(route.routes[0].overviewPolyline.points);
        // print("Length is: " + routeInfo.length.toString());
        //print(routeInfo[0].toString());

        for (var mul_point in trueWay) {
          points.add(LatLng(mul_point.latitude, mul_point.longitude));
        }
      }
      //usrSelections.clear();
      _AddRoute();
    }
  }


  Future <void> _ZoomInMyLocation(double maplat, double maplng) async{
    mapController.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(
                target: LatLng(maplat,maplng),
                zoom: 15.0)
        )
    );
  }

  void _getLocation() async {
    var currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    _ZoomInMyLocation(currentLocation.latitude, currentLocation.longitude);

    setState(() {
      a = Location(currentLocation.latitude, currentLocation.longitude);
      usr_points[0] = LatLng(currentLocation.latitude, currentLocation.longitude);
      haveFrom = true;

      final marker = Marker(
        markerId: MarkerId("curr_loc"),
        position: LatLng(currentLocation.latitude, currentLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: 'Your Location'),

      );
      if(markers != null){
        markers.removeWhere((item) => item.markerId == MarkerId("curr_loc"));
        markers.removeWhere((item) => item.markerId == MarkerId("From"));
      }
      markers.add(marker);
      getAddress(currentLocation.latitude, currentLocation.longitude).then((value){
        fromAdres = value;
      });
      getDirectForUsr();
    });

  }

  Future <String> getAddress(double lat, double lng) async{
    Coordinates coordinates = new Coordinates(lat, lng);
   // LocationManager myLoc;
    //myLoc.setFromLat(lat); myLoc.setFromLng(lng);

    //print("Testing setters: " + myLoc.FromLat().toString() + "   " + myLoc.FromLng().toString());
    var addresses = await Geocoder.local.findAddressesFromCoordinates(coordinates);

    //String output = addresses.first.featureName + " " + addresses.first.addressLine;
    String output = addresses.first.addressLine;
    return output;
    //return a;
  }



}





/*
class getLocationFromInput(){

}

 */