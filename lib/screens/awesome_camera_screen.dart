import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class AwesomeCameraScreen extends StatelessWidget {
  const AwesomeCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photo(
          pathBuilder: (sensors) async {
            final Directory extDir = await getTemporaryDirectory();
            final String dirPath = '${extDir.path}/Pictures/好好拍';
            await Directory(dirPath).create(recursive: true);
            final String filePath =
                '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
            return SingleCaptureRequest(filePath, sensors.first);
          },
        ),
        onMediaTap: (mediaCapture) {
          mediaCapture.captureRequest.when(
            single: (single) {
              debugPrint('Photo captured: ${single.file?.path}');
            },
            multiple: (multiple) {
              multiple.fileBySensor.forEach((key, value) {
                debugPrint('Multiple photo taken: $key ${value?.path}');
              });
            },
          );
        },
        theme: AwesomeTheme(
          bottomActionsBackgroundColor: Colors.transparent,
          buttonTheme: AwesomeButtonTheme(
            backgroundColor: Colors.white,
          ),
        ),
        previewFit: CameraPreviewFit.cover,
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          aspectRatio: CameraAspectRatios.ratio_1_1,
          flashMode: FlashMode.auto,
        ),
        progressIndicator: const Center(
          child: CircularProgressIndicator(),
        ),
        topActionsBuilder: (state) {
          return Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AwesomeFlashButton(state: state),
                AwesomeCameraSwitchButton(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}
