
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
const kGoogleApiKey = "AIzaSyAtkORU-7NcIIy-zd8cVPRSP8BdNhDofE4";

//******************** DEBUGGING ONLY !!! ********************
/*
void main() => runApp(MaterialApp(
  initialRoute: 'init',
  routes:  <String, WidgetBuilder>{
    'init': (context) => MyCustomLocationButton(),


  },
));
*/
//******************** DEBUGGING ONLY !!! ********************

//*********************** "From" and "To" coordinates storage **********************
class LocationManager{

  //********************* From and To variables *********************

  double _fromLat, _fromLng;
  double _toLat, _toLng;

  //********************* From and To variables *********************
  //****************** Setters and Getters of _fromLat ******************
  void setFromLat(double fromLat){
    _fromLat = fromLat;
  }
  void setFromLng(double fromLng){
    _fromLng = fromLng;
  }
  double FromLat(){  // Use this to get lattitude of "From"
    return _fromLat;
  }
  double FromLng(){  // Use this to get lattitude of "To"
    return _fromLng;
  }
  //****************** Setters and Getters of _fromLat ******************

  //****************** Setters and Getters of _toLat ******************


  void setToLat(double toLat){
    _toLat = toLat;
  }
  void setToLng(double toLng){
    _toLng = toLng;
  }
  double ToLat(){
    return _toLat;
  }
  double ToLng(){
    return _toLng;
  }

  //****************** Setters and Getters of _toLat ******************

}

//*********************** "From" and "To" coordinates storage **********************


class usrLocPermit extends StatefulWidget {
  @override
  _usrLocPermitState createState() => _usrLocPermitState();
}

class _usrLocPermitState extends State<usrLocPermit> {
  @override
  PermissionStatus _locStatus;
  void initState(){
    super.initState();
    PermissionHandler().checkPermissionStatus(PermissionGroup.location).then(updateStatus);
    askPermission();

  }
  void updateStatus (PermissionStatus status){
    if(status != _locStatus){
      setState(() {
        status = _locStatus;
      });
    }
    else{Navigator.pushReplacementNamed(context, 'home');}
  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: AppBar(
          centerTitle: true,
          elevation: 0.0,
          title:
          Align(
            alignment: Alignment.center,

              child: Text(
                  "Route Optimization" ,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,

                  )
              ),

          ),
          backgroundColor: Colors.red,
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(

            child:Align(
              alignment: Alignment.center,
              child: RaisedButton(

                onPressed:() {

                  Navigator.pushReplacementNamed(context, 'home');
                },
                child: Text("Get started", style: TextStyle(fontWeight: FontWeight.bold)),

              ),
            ),

          ),
        ],
      ),
    );
  }
  void askPermission(){
    PermissionHandler().requestPermissions([PermissionGroup.location]).then(onStatusRequested);

  }
  void onStatusRequested(Map<PermissionGroup, PermissionStatus> statuses){
    final status = statuses[PermissionGroup.location];
    if (status != PermissionStatus.granted){
      PermissionHandler().openAppSettings();
    }else{
      //Navigator.pushReplacementNamed(context, 'home');

      updateStatus(status);
    }
  }
}

