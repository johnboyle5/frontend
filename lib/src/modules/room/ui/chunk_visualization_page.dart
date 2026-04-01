import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' show SoliplexApi;

class ChunkVisualizationPage extends StatefulWidget {
  const ChunkVisualizationPage({
    super.key,
    required this.api,
    required this.roomId,
    required this.chunkId,
    required this.documentTitle,
    required this.pageNumbers,
  });

  final SoliplexApi api;
  final String roomId;
  final String chunkId;
  final String documentTitle;
  final List<int> pageNumbers;

  static Future<void> show({
    required BuildContext context,
    required SoliplexApi api,
    required String roomId,
    required String chunkId,
    required String documentTitle,
    required List<int> pageNumbers,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ChunkVisualizationPage(
        api: api,
        roomId: roomId,
        chunkId: chunkId,
        documentTitle: documentTitle,
        pageNumbers: pageNumbers,
      ),
    );
  }

  @override
  State<ChunkVisualizationPage> createState() => _ChunkVisualizationPageState();
}

class _ChunkVisualizationPageState extends State<ChunkVisualizationPage> {
  late Future<List<Uint8List>> _future;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, int> _rotations = {};

  @override
  void initState() {
    super.initState();
    _loadVisualization();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadVisualization() {
    _future = widget.api
        .getChunkVisualization(widget.roomId, widget.chunkId)
        .then((viz) => viz.imagesBase64.map(base64Decode).toList());
  }

  void _retry() {
    setState(() {
      _rotations.clear();
      _loadVisualization();
    });
  }

  void _rotate(int pageIndex) {
    setState(() {
      _rotations[pageIndex] = ((_rotations[pageIndex] ?? 0) + 1) % 4;
    });
  }

  String _pageLabel(int index, int total) {
    if (widget.pageNumbers.isNotEmpty && index < widget.pageNumbers.length) {
      return 'Page ${widget.pageNumbers[index]}';
    }
    return 'Image ${index + 1} of $total';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(context),
            Expanded(
              child: FutureBuilder<List<Uint8List>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _buildError(context, snapshot.error!);
                  }
                  return _buildImages(context, snapshot.data ?? const []);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.documentTitle,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Failed to load visualization',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context, List<Uint8List> images) {
    if (images.isEmpty) {
      return const Center(child: Text('No page images available'));
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final rotation = _rotations[index] ?? 0;
              return Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: RotatedBox(
                        quarterTurns: rotation,
                        child: Image.memory(
                          images[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => _rotate(index),
                      icon: const Icon(Icons.rotate_right),
                      tooltip: 'Rotate',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                _pageLabel(_currentPage, images.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: index == _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
