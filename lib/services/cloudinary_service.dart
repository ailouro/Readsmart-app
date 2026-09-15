import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'tlhtowg9';
  static const String uploadPreset = 'zxpjpyfe';

  static Uri get _uploadUri =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  static Future<String> uploadImageBytes(
    Uint8List bytes, {
    required String filename,
    String folder = 'stories',
  }) async {
    if (cloudName == 'YOUR_CLOUD_NAME' ||
        uploadPreset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw Exception(
        'Cloudinary is not configured yet. Set cloudName and uploadPreset '
        'in lib/services/cloudinary_service.dart',
      );
    }

    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Cloudinary upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary response did not include a secure_url: ${response.body}',
      );
    }
    return secureUrl;
  }
}
