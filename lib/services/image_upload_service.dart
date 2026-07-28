import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:taskassassin/supabase/supabase_config.dart';

class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  // Upload image to Supabase Storage
  Future<String> uploadMissionPhoto({
    required String missionId,
    required bool isBefore,
    required Uint8List bytes,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${isBefore ? 'before' : 'after'}-$timestamp.jpg';
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw StateError('Sign in before uploading a photo.');
      final fullPath = '$userId/missions/$missionId/$fileName';

      final uploadBytes = await compute(_prepareMissionPhoto, bytes);
      await _uploadWithRetry(fullPath, uploadBytes);

      final publicUrl = SupabaseConfig.client.storage
          .from('user-uploads')
          .getPublicUrl(fullPath);

      debugPrint('[ImageUploadService] Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[ImageUploadService] Upload error: $e');
      rethrow;
    }
  }

  Future<void> _uploadWithRetry(String fullPath, Uint8List bytes) async {
    final session = SupabaseConfig.auth.currentSession;
    if (session == null) throw StateError('Sign in before uploading a photo.');

    final encodedPath = fullPath.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse(
      '${SupabaseConfig.supabaseUrl}/storage/v1/object/user-uploads/$encodedPath',
    );

    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final client = http.Client();
      try {
        final response = await client
            .post(
              uri,
              headers: {
                'apikey': SupabaseConfig.anonKey,
                'Authorization': 'Bearer ${session.accessToken}',
                'Content-Type': 'image/jpeg',
                'x-upsert': 'true',
              },
              body: bytes,
            )
            .timeout(const Duration(seconds: 45));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
        lastError = StateError(
          'Photo upload failed (${response.statusCode}): ${response.body}',
        );
      } catch (error) {
        lastError = error;
      } finally {
        client.close();
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
    throw lastError ?? StateError('Photo upload failed.');
  }

  Future<String> uploadUserAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId != userId) {
        throw StateError('You can only upload your own avatar.');
      }
      final fullPath = '$userId/avatar.jpg';

      await SupabaseConfig.client.storage
          .from('user-uploads')
          .uploadBinary(fullPath, bytes);

      final publicUrl = SupabaseConfig.client.storage
          .from('user-uploads')
          .getPublicUrl(fullPath);

      debugPrint('[ImageUploadService] Avatar uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[ImageUploadService] Avatar upload error: $e');
      rethrow;
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex =
          pathSegments.indexWhere((s) => s == 'object' || s == 'public');
      if (bucketIndex == -1) throw 'Invalid URL format';

      final bucket = pathSegments[bucketIndex + 1];
      final path = pathSegments.skip(bucketIndex + 2).join('/');

      await SupabaseConfig.client.storage.from(bucket).remove([path]);
      debugPrint('[ImageUploadService] Image deleted: $path');
    } catch (e) {
      debugPrint('[ImageUploadService] Delete error: $e');
      rethrow;
    }
  }
}

Uint8List _prepareMissionPhoto(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return bytes;
  const maxEdge = 1600;
  final longestEdge =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longestEdge > maxEdge
      ? image.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxEdge : null,
          height: decoded.height > decoded.width ? maxEdge : null,
          interpolation: image.Interpolation.linear,
        )
      : decoded;
  return Uint8List.fromList(image.encodeJpg(resized, quality: 82));
}
