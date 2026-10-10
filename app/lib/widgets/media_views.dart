import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../app_state.dart';
import '../theme.dart';

// media is either 'local:<path>' (still in the outbox) or the server filename.
VideoPlayerController playerFor(BuildContext context, String media) {
  if (media.startsWith('local:')) return VideoPlayerController.file(File(media.substring(6)));
  final api = context.read<AppState>().api!;
  return VideoPlayerController.networkUrl(Uri.parse(api.mediaUrl(media)), httpHeaders: api.authHeader);
}

// Encrypted media ("e2e:<file>|<key>") is downloaded and decrypted once, then shown from the local copy.
class E2eMedia extends StatelessWidget {
  final String media, name;
  final Widget Function(String media) builder;
  const E2eMedia({super.key, required this.media, required this.name, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!media.startsWith('e2e:')) return builder(media);
    final e = context.read<AppState>().e2ee;
    if (e == null) return builder(media);
    return FutureBuilder<File>(
      future: e.openFile(media, name),
      builder: (_, snap) {
        if (snap.hasData) return builder('local:${snap.data!.path}');
        return SizedBox(
          width: 240,
          height: 64,
          child: Center(
            child: snap.hasError
                ? Text('Could not decrypt this file', style: TextStyle(color: C.danger))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Decrypting…', style: TextStyle(color: C.muted)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class VideoTile extends StatelessWidget {
  final String media, name;
  const VideoTile(this.media, this.name, {super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoScreen(media: media, name: name),
      ),
    ),
    child: Container(
      width: 240,
      height: 150,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Video' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class VideoScreen extends StatefulWidget {
  final String media, name;
  const VideoScreen({super.key, required this.media, required this.name});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController _v;
  String? _err;

  @override
  void initState() {
    super.initState();
    _v = playerFor(context, widget.media)..addListener(() => mounted ? setState(() {}) : null);
    _v.initialize().then((_) => _v.play(), onError: (_) => setState(() => _err = 'Could not play this video.'));
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final val = _v.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _err != null
            ? Text(_err!, style: TextStyle(color: C.muted))
            : !val.isInitialized
            ? const CircularProgressIndicator()
            : GestureDetector(
                onTap: () => val.isPlaying ? _v.pause() : _v.play(),
                child: AspectRatio(
                  aspectRatio: val.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_v),
                      if (!val.isPlaying) const Center(child: Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70)),
                      VideoProgressIndicator(_v, allowScrubbing: true, colors: VideoProgressColors(playedColor: C.accent)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// Inline voice/audio player; the controller is only created on first play.
class AudioTile extends StatefulWidget {
  final String media, name;
  const AudioTile(this.media, this.name, {super.key});
  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  VideoPlayerController? _p;
  bool _loading = false;

  Future<void> _toggle() async {
    if (_p == null) {
      setState(() => _loading = true);
      final p = playerFor(context, widget.media)..addListener(() => mounted ? setState(() {}) : null);
      try {
        await p.initialize();
      } catch (_) {
        p.dispose();
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play this audio.')));
        }
        return;
      }
      _p = p;
      _loading = false;
    }
    final p = _p!;
    if (p.value.isPlaying) {
      await p.pause();
    } else {
      if (p.value.position >= p.value.duration) await p.seekTo(Duration.zero);
      await p.play();
    }
  }

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _p?.value;
    final pos = v?.position ?? Duration.zero, dur = v?.duration ?? Duration.zero;
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _loading ? null : _toggle,
            tooltip: v?.isPlaying == true ? 'Pause' : 'Play',
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(v?.isPlaying == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name.isEmpty ? 'Audio' : widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: dur.inMilliseconds == 0 ? 0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0, 1),
                  color: C.accent,
                  backgroundColor: C.line,
                ),
                const SizedBox(height: 2),
                Text(v == null ? 'Tap to play' : '${_clock(pos)} / ${_clock(dur)}', style: TextStyle(fontSize: 11, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Documents: download once to the app cache, then open in the phone's own viewer.
class FileTile extends StatefulWidget {
  final String media, name;
  const FileTile(this.media, this.name, {super.key});
  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _busy = false;

  // Installers, scripts and macro documents can harm the phone: confirm before opening.
  static const risky = {'apk', 'exe', 'msi', 'bat', 'cmd', 'sh', 'ps1', 'vbs', 'js', 'jar', 'scr', 'com', 'docm', 'xlsm', 'pptm', 'dotm'};

  Future<void> _open() async {
    final ext = widget.name.contains('.') ? widget.name.split('.').last.toLowerCase() : '';
    if (risky.contains(ext) || ext.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: Icon(Icons.gpp_maybe_rounded, color: C.danger, size: 36),
          title: const Text('Potentially harmful file'),
          content: Text(
            ext.isEmpty
                ? 'This file has no type, so Bunny Hop cannot tell what it does. Only open it if you trust the sender.'
                : '".$ext" files can install apps or run code on your phone. Only open it if you trust the sender.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Open anyway', style: TextStyle(color: C.danger)),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final msg = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api!;
    setState(() => _busy = true);
    try {
      var path = widget.media.startsWith('local:') ? widget.media.substring(6) : null;
      if (path == null) {
        final dir = Directory('${(await getApplicationCacheDirectory()).path}/files/${widget.media.split('.').first}');
        final f = File('${dir.path}/${widget.name.isEmpty ? widget.media : widget.name.replaceAll(RegExp(r'[\\/]'), '_')}');
        if (!await f.exists()) {
          final r = await http.get(Uri.parse(api.mediaUrl(widget.media)), headers: api.authHeader).timeout(const Duration(minutes: 3));
          if (r.statusCode != 200) throw Exception('download failed');
          await dir.create(recursive: true);
          await f.writeAsBytes(r.bodyBytes);
        }
        path = f.path;
      }
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done) msg.showSnackBar(SnackBar(content: Text('No app on this phone can open it (${res.message}).')));
    } catch (_) {
      msg.showSnackBar(const SnackBar(content: Text('Could not download the file. Are you connected?')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _busy ? null : _open,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _busy
              ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.insert_drive_file_rounded, size: 28, color: C.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name.isEmpty ? 'File' : widget.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(_busy ? 'Opening…' : 'Tap to open', style: TextStyle(fontSize: 11, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
