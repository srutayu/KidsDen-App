import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';

class UploadService {
  static Future<void> uploadFiles({
    required String authToken,
    required String classId,
    required String currentUserId,
    required String? currentUserRole,
    required List<dynamic> messages,
    required Set<String> uploadingKeys,
    required String baseUrl,
    required Function(void Function()) setState,
    required bool mounted,
  }) async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'files',
        extensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov', 'doc', 'docx'],
      );

      final List<XFile>? files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files == null || files.isEmpty) return;

      final selection = files.take(10).toList();
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

      final filesMeta = <Map<String, String>>[];
      for (int i = 0; i < selection.length; i++) {
        final f = selection[i];
        final ext = f.name.split('.').last;
        final newName = selection.length == 1
            ? 'file_${baseTimestamp}.$ext'
            : 'file_${baseTimestamp}_${i + 1}.$ext';
        filesMeta.add({
          'fileName': newName,
          'contentType': f.mimeType ?? 'application/octet-stream',
        });
      }

      // 1️⃣ Request presigned URLs
      final presignRes = await http.post(
        Uri.parse('$baseUrl/classes/request-presign'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json'
        },
        body: json.encode({'files': filesMeta, 'classId': classId}),
      );

      if (presignRes.statusCode != 200) {
        print('Presign request failed: ${presignRes.statusCode} ${presignRes.body}');
        return;
      }

      final presignData = json.decode(presignRes.body);
      final presignedFiles = presignData['files'] as List<dynamic>? ?? [];
      final presignMap = {for (var p in presignedFiles) p['fileName']: p};

      // 2️⃣ Upload each file
      for (int i = 0; i < selection.length; i++) {
        final f = selection[i];
        final ext = f.name.split('.').last;
        final newName = selection.length == 1
            ? 'file_${baseTimestamp}.$ext'
            : 'file_${baseTimestamp}_${i + 1}.$ext';

        try {
          final bytes = await f.readAsBytes();
          final pres = presignMap[newName];
          if (pres == null) continue;

          final uploadUrl = pres['uploadUrl'];
          final getUrl = pres['getUrl'];
          final key = pres['key'];

          // Local preview optimistic message
          try {
            final base64Data = base64Encode(bytes);
            final tempId =
                'local_${DateTime.now().millisecondsSinceEpoch}_$newName';
            final tempMessage = {
              '_id': tempId,
              'content': json.encode({
                'type': 'file',
                'key': key,
                'localPreviewBase64': base64Data,
                'mime': f.mimeType ?? 'application/octet-stream',
                'name': newName
              }),
              'sender': currentUserId,
              'senderRole': currentUserRole,
              'timestamp': DateTime.now().toIso8601String(),
              'classId': classId,
            };

            if (mounted) {
              setState(() {
                messages.add(tempMessage);
                uploadingKeys.add(tempId);
              });
            } else {
              messages.add(tempMessage);
              uploadingKeys.add(tempId);
            }
          } catch (e) {
            print('Error creating local preview: $e');
          }

          // Upload to S3
          final putRes = await http.put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': f.mimeType ?? 'application/octet-stream'},
            body: bytes,
          );

          if (putRes.statusCode != 200 && putRes.statusCode != 204) {
            print('PUT to S3 failed for $newName: ${putRes.statusCode}');
            continue;
          }

          // Confirm upload
          final confirmRes = await http.post(
            Uri.parse('$baseUrl/classes/confirm-upload'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json'
            },
            body: json.encode({
              'key': key,
              'classId': classId,
              'getUrl': getUrl,
              'contentType': f.mimeType ?? 'application/octet-stream',
              'name': newName,
              'size': bytes.length
            }),
          );

          if (confirmRes.statusCode == 200) {
            print('Upload confirmed for $newName');
          } else {
            print('Confirm failed: ${confirmRes.statusCode}');
          }
        } catch (e) {
          print('Error uploading file ${f.name}: $e');
        }
      }
    } catch (e) {
      print('Error uploading files: $e');
    }
  }
}


