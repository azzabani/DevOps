// lib/services/cloudinary_service.dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dcybufgn2';
  static const String _uploadPreset = 'azzamobile';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/dcybufgn2/image/upload';

  /// Upload des bytes d'image vers Cloudinary
  /// Retourne l'URL sécurisée de l'image uploadée
  static Future<String> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = 'flutter_booking/resources';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    } else {
      final error = json.decode(response.body);
      throw Exception(
          'Cloudinary upload failed: ${error['error']?['message'] ?? response.body}');
    }
  }
}
