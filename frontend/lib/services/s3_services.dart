import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

Future<List<XFile>> pickFiles() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: [
      'jpg',
      'jpeg',
      'png',
      'pdf',
      'mp4',
      'mov',
      'doc',
      'docx',
    ],
  );

  if (result == null || result.files.isEmpty) {
    return [];
  }

  // ✅ Wrap picked files into XFile objects (to keep same datatype)
  final List<XFile> xFiles = result.files
      .where((f) => f.path != null)
      .map((f) => XFile(f.path!))
      .toList();

  return xFiles;
}

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
      final List<XFile> files = await pickFiles();
      if (files.isEmpty) return;

      final selection = files.take(10).toList();
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
      String guessMimeType(String name) {
        final ext = name.split('.').last.toLowerCase();
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          case 'mp4':
          case 'mov':
            return 'video/mp4';
          case 'pdf':
            return 'application/pdf';
          case 'doc':
          case 'docx':
            return 'application/msword';
          default:
            return 'application/octet-stream';
        }
      }

      final filesMeta = <Map<String, String>>[];
      for (int i = 0; i < selection.length; i++) {
        final f = selection[i];
        final ext = f.name.split('.').last;
        final newName = selection.length == 1
            ? 'file_$baseTimestamp.$ext'
            : 'file_${baseTimestamp}_${i + 1}.$ext';
        filesMeta.add({
          'fileName': newName,
          'contentType': guessMimeType(f.name),


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
        final ext = f.name.split('.').last.toLowerCase();
        final newName = selection.length == 1
            ? 'file_$baseTimestamp.$ext'
            : 'file_${baseTimestamp}_${i + 1}.$ext';

        try {
          List<int> bytes;
          String contentType = guessMimeType(f.name);
          // Compress images
          if (_isImage(ext)) {
            bytes = await _compressImage(f);
          }
          // Compress videos
          else if (_isVideo(ext)) {
            final compressedFile = await _compressVideo(f);
            print('after compression');
            if (compressedFile != null) {
              bytes = await compressedFile.readAsBytes();
              // Clean up temporary file after reading
              await compressedFile.delete();
            } else {
              // Fallback to original if compression fails
              bytes = await f.readAsBytes();
            }
          }
          // Other files (PDF, DOC, etc.) - no compression
          else {
            bytes = await f.readAsBytes();
          }

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
                'mime': contentType,
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
            headers: {'Content-Type': contentType},
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
              'contentType': contentType,
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

  // Helper method to check if file is an image
  static bool _isImage(String extension) {
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  // Helper method to check if file is a video
  static bool _isVideo(String extension) {
    return ['mp4', 'mov'].contains(extension);
  }

  // Compress image to 1080p if higher resolution
  static Future<List<int>> _compressImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      
      // Compress image with 1080p max dimension
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1920,
        minHeight: 1080,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      
      print('Image compressed: ${bytes.length} -> ${result.length} bytes');
      return result;
    } catch (e) {
      print('Error compressing image: $e');
      // Return original bytes if compression fails
      return await file.readAsBytes();
    }
  }

  // Compress video to 1080p if higher resolution
  static Future<File?> _compressVideo(XFile file) async {
    try {
      final filePath = file.path;
      
      // Get video info to check resolution
      final info = await VideoCompress.getMediaInfo(filePath);
      
      // Only compress if video is higher than 1080p
      if (info.width != null && info.height != null) {        
        final compressedInfo = await VideoCompress.compressVideo(
            filePath,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );
          
          if (compressedInfo != null && compressedInfo.file != null) {
            print('Video compressed: ${info.filesize} -> ${compressedInfo.filesize} bytes');
            return compressedInfo.file;
          }
      }
      
      // If no compression needed or failed, return original file
      return File(filePath);
    } catch (e) {
      print('Error compressing video: $e');
      return File(file.path);
    }
  }
}