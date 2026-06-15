import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  static const _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );
  static const _rootFolder = String.fromEnvironment(
    'CLOUDINARY_FOLDER',
    defaultValue: 'futconecta',
  );

  final http.Client _client;

  Future<String> uploadProfilePhoto(String userId, XFile file) {
    return _uploadToCloudinary(
      file: file,
      resourceType: 'image',
      folder: '$_rootFolder/players/$userId/profile',
      timeout: const Duration(seconds: 60),
    );
  }

  Future<String> uploadPlayerVideo(String playerId, XFile file) {
    return _uploadToCloudinary(
      file: file,
      resourceType: 'video',
      folder: '$_rootFolder/players/$playerId/videos',
      timeout: const Duration(minutes: 3),
    );
  }

  Future<String> uploadFeedImage(String userId, XFile file) {
    return _uploadToCloudinary(
      file: file,
      resourceType: 'image',
      folder: '$_rootFolder/feed/$userId',
      timeout: const Duration(seconds: 60),
    );
  }

  Future<String> _uploadToCloudinary({
    required XFile file,
    required String resourceType,
    required String folder,
    required Duration timeout,
  }) async {
    _validateConfig();

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudName/$resourceType/upload',
    );
    final bytes = await file.readAsBytes().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw TimeoutException('Nao foi possivel ler o arquivo selecionado.');
      },
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name.isEmpty ? 'futconecta-upload' : file.name,
        ),
      );

    final streamedResponse = await _client
        .send(request)
        .timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              resourceType == 'video'
                  ? 'O upload do video demorou demais. Tente um arquivo menor ou verifique a internet.'
                  : 'O upload da imagem demorou demais. Verifique a internet.',
            );
          },
        );
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decodeBody(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _cloudinaryError(body);
      throw Exception('Cloudinary (${response.statusCode}): $message');
    }

    final secureUrl = body['secure_url']?.toString();
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary nao retornou a URL do arquivo enviado.');
    }
    return secureUrl;
  }

  void _validateConfig() {
    if (_cloudName.isEmpty ||
        _uploadPreset.isEmpty ||
        _cloudName == 'SEU_CLOUD_NAME' ||
        _uploadPreset == 'SEU_UPLOAD_PRESET') {
      throw Exception(
        'Configure CLOUDINARY_CLOUD_NAME e CLOUDINARY_UPLOAD_PRESET no launch.json.',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  String _cloudinaryError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? 'falha no upload';
    }
    return 'falha no upload';
  }
}
