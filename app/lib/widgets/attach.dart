import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../app_state.dart';
import '../theme.dart';

class Attachment {
  final String path, type, name;
  final int size;
  const Attachment(this.path, this.type, this.name, this.size);
}

String fmtSize(int b) => b < 1024
    ? '$b B'
    : b < 1 << 20
    ? '${(b / 1024).toStringAsFixed(0)} KB'
    : '${(b / (1 << 20)).toStringAsFixed(1)} MB';

const _audioExt = {'m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus', 'amr', 'flac'};
const _videoExt = {'mp4', 'mov', '3gp', 'webm', 'mkv'};
const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};

String typeFor(String name) {
  final ext = name.split('.').last.toLowerCase();
  return _imageExt.contains(ext)
      ? 'image'
      : _videoExt.contains(ext)
      ? 'video'
      : _audioExt.contains(ext)
      ? 'audio'
      : 'file';
}

// Choose source -> pick -> size check against the server limit -> preview -> confirmed attachment.
Future<Attachment?> pickAttachment(BuildContext context) async {
  final src = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.panel,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Wrap(
        children: [
          for (final (v, icon, label) in [
            ('camera', Icons.photo_camera_outlined, 'Take photo'),
            ('gallery', Icons.photo_library_outlined, 'Photo from gallery'),
            ('record', Icons.videocam_outlined, 'Record video'),
            ('video', Icons.video_library_outlined, 'Video from gallery'),
            ('audio', Icons.audiotrack_outlined, 'Audio'),
            ('file', Icons.insert_drive_file_outlined, 'Document or other file'),
          ])
            ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(c, v)),
        ],
      ),
    ),
  );
  if (src == null || !context.mounted) return null;
  final a = await _pick(src);
  if (a == null || !context.mounted) return null;
  final max = context.read<AppState>().maxUploadBytes;
  if (a.size > max) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: C.danger,
          content: Text('${a.name} is ${fmtSize(a.size)}. The limit is ${fmtSize(max)}, so it was not sent.'),
        ),
      );
    return null;
  }
  return showModalBottomSheet<Attachment>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    showDragHandle: true,
    builder: (_) => _Preview(a),
  );
}

Future<Attachment?> _pick(String src) async {
  final ip = ImagePicker();
  XFile? x;
  switch (src) {
    case 'camera' || 'gallery':
      // resized on device so uploads stay small on a busy network
      x = await ip.pickImage(
        source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
    case 'record' || 'video':
      x = await ip.pickVideo(source: src == 'record' ? ImageSource.camera : ImageSource.gallery);
    default:
      final f = await FilePicker.pickFile(type: src == 'audio' ? FileType.audio : FileType.any);
      if (f == null) return null;
      final path = f.path ?? await _copyToTemp(f);
      final size = await File(path).length();
      return Attachment(path, src == 'audio' ? 'audio' : typeFor(f.name), f.name, size);
  }
  if (x == null) return null;
  final type = src == 'camera' || src == 'gallery' ? 'image' : 'video';
  return Attachment(x.path, type, x.name, await x.length());
}

// Content URIs (no file path) are copied so the outbox can upload them later.
Future<String> _copyToTemp(PlatformFile f) async {
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}');
  final sink = out.openWrite();
  await sink.addStream(f.readAsByteStream());
  await sink.close();
  return out.path;
}

class _Preview extends StatefulWidget {
  final Attachment a;
  const _Preview(this.a);
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  VideoPlayerController? _v;

  @override
  void initState() {
    super.initState();
    if (widget.a.type == 'video') {
      _v = VideoPlayerController.file(File(widget.a.path))..initialize().then((_) => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _v?.dispose();
    super.dispose();
  }

  Widget _media() {
    final a = widget.a;
    if (a.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(a.path), height: 280, fit: BoxFit.contain),
      );
    }
    final v = _v;
    if (v != null) {
      if (!v.value.isInitialized) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
      return GestureDetector(
        onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: AspectRatio(
              aspectRatio: v.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(v),
                  if (!v.value.isPlaying) const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(14)),
      child: Icon(a.type == 'audio' ? Icons.audiotrack_rounded : Icons.insert_drive_file_rounded, size: 56, color: C.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _media()),
            const SizedBox(height: 12),
            Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            Text(
              fmtSize(a.size),
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, a),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
