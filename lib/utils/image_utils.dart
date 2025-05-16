import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  /// Compresses an image and checks if it meets the size requirements
  /// Returns compressed file path if successful, null if unable to meet size requirement
  static Future<String?> compressAndValidateImage(String imagePath, {int maxSizeKB = 50}) async {
    try {
      // Check original file size
      File imageFile = File(imagePath);
      int originalSizeBytes = await imageFile.length();

      // If already under the limit, return the original path
      if (originalSizeBytes <= maxSizeKB * 1024) {
        return imagePath;
      }

      // Load the image
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        print('Could not decode image');
        return null;
      }

      // Get temp directory for saving the compressed file
      final tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Try different quality levels until we get below the size limit
      for (int quality = 90; quality >= 5; quality -= 10) {
        // Resize if image is too large
        img.Image resizedImage = originalImage;
        if (originalImage.width > 1024 || originalImage.height > 1024) {
          if (originalImage.width > originalImage.height) {
            resizedImage = img.copyResize(
              originalImage,
              width: 800,
              interpolation: img.Interpolation.linear,
            );
          } else {
            resizedImage = img.copyResize(
              originalImage,
              height: 800,
              interpolation: img.Interpolation.linear,
            );
          }
        }

        // Encode with current quality
        final compressedBytes = img.encodeJpg(resizedImage, quality: quality);

        // Write to file
        final compressedFile = File(targetPath);
        await compressedFile.writeAsBytes(compressedBytes);

        // Check if it's now under the size limit
        final compressedSize = await compressedFile.length();
        if (compressedSize <= maxSizeKB * 1024) {
          print('Successfully compressed from ${originalSizeBytes/1024}KB to ${compressedSize/1024}KB with quality $quality');
          return targetPath;
        }
      }

      // If we get here, we couldn't compress enough
      print('Failed to compress image below ${maxSizeKB}KB');
      return null;
    } catch (e) {
      print('Error in image compression: $e');
      return null;
    }
  }
}