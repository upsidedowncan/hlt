import 'package:flutter/material.dart';

class AiSpeedDial extends StatefulWidget {
  final VoidCallback onNewChatPressed;
  final VoidCallback onVisualizationPressed;

  const AiSpeedDial({
    super.key,
    required this.onNewChatPressed,
    required this.onVisualizationPressed,
  });

  @override
  State<AiSpeedDial> createState() => _AiSpeedDialState();
}

class _AiSpeedDialState extends State<AiSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDial() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onNewChatPressed() {
    _toggleDial();
    widget.onNewChatPressed();
  }

  void _onVisualizationPressed() {
    _toggleDial();
    widget.onVisualizationPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visualization FAB
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton(
              onPressed: _onVisualizationPressed,
              heroTag: 'visualization_fab',
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              mini: true,
              tooltip: 'New Visualization',
              child: const Icon(Icons.show_chart),
            ),
          ),
        ),

        // New Chat FAB
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton(
              onPressed: _onNewChatPressed,
              heroTag: 'new_chat_fab',
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              mini: true,
              tooltip: 'New Chat',
              child: const Icon(Icons.add),
            ),
          ),
        ),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleDial,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: const Icon(Icons.smart_toy),
        ),
      ],
    );
  }
}