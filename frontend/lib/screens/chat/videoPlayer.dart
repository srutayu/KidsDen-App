import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl; // can be a network URL or local file path
  final bool isLocal;
  final String senderID;  

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.isLocal,
    required this.senderID
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late String token;
  String senderName='';
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    fetchUserName(widget.senderID, token);
    _initializePlayer();
  }


 Future<void> fetchUserName(String userId, String authToken) async {
    final name = await AuthController.getNamefromID(token, userId);
    setState(() {
      senderName = name;
    });
  }

  Future<void> _initializePlayer() async {
    try {
      // Initialize controller based on local or network
      if (widget.isLocal) {
        _videoController = VideoPlayerController.file(File(widget.videoUrl));
      } else {
        // ignore: deprecated_member_use
        _videoController = VideoPlayerController.network(widget.videoUrl);
      }

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      print("Error initializing video: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          senderName,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading || _chewieController == null
            ? const CircularProgressIndicator()
            : (_chewieController!.videoPlayerController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _chewieController!
                        .videoPlayerController.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : const CircularProgressIndicator()),
      ),
    );
  }
}
