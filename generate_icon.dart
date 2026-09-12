import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final file = File('assets/images/SleepAstra_logo_transparent.png');
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);
  
  if (image == null) {
    print('Failed to decode image');
    return;
  }
  
  // Make all non-transparent pixels solid white
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a > 0) {
        // Set rgb to 255 (white) but keep alpha
        image.setPixelRgba(x, y, 255, 255, 255, pixel.a);
      }
    }
  }
  
  final sizes = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96
  };
  
  for (var entry in sizes.entries) {
    final density = entry.key;
    final size = entry.value;
    
    final resized = img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.linear);
    
    final dir = Directory('android/app/src/main/res/drawable-$density');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final outFile = File('${dir.path}/ic_notification.png');
    await outFile.writeAsBytes(img.encodePng(resized));
    print('Wrote ${outFile.path}');
  }
  print('Done.');
}
