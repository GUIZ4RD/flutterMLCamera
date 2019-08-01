import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;



List<CameraDescription> cameras;

Future<void> main() async {
  cameras = await availableCameras();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {


  final String MODEL_URL = "PUT YOUR ENDPOINT HERE";


  CameraController controller;
  bool pressed=false;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }




  imglib.Image convertYUV420toImageColor(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel;

      var img = imglib.Image(width, height);

      for(int x=0; x < width; x++) {
        for(int y=0; y < height; y++) {
          final int uvIndex = uvPixelStride * (x/2).floor() + uvRowStride*(y/2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 -vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          img.data[index] = (0xFF << 24) | (b << 16) | (g << 8) | r;
        }
      }

      return img;
    } catch (e) {
      print("ERROR:" + e.toString());
    }
    return null;
  }


  void detect(CameraImage image) async{

    imglib.Image myimage = convertYUV420toImageColor(image);
    myimage = imglib.copyResizeCropSquare(myimage, 128);
    myimage = imglib.copyRotate(myimage, 90);
    Uint8List data = myimage.getBytes(format: imglib.Format.luminance);

    var body = json.encode({"data": [data]});

    http.Response response = await http.post(MODEL_URL, body: body,
        headers: {'content-type': 'application/json'});

    debugPrint("Response status: ${response.statusCode}");
    debugPrint("Response body: ${response.body}");

    Fluttertoast.showToast(
        msg: response.body,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }


  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }

    controller.startImageStream((CameraImage image){
      if(pressed){
        detect(image);
        pressed=false;

      }
    });


    return MaterialApp(
        home: Column(
          children: <Widget>[

            Expanded(
              child: CameraPreview(controller),
            ),

            RaisedButton(
              child: Text('capture'),
              onPressed: ()=>(pressed=true),
            )
          ],
        )
    );

  }
}