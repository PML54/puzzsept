import 'package:flutter/material.dart';

class CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoading;
  final String loadingText;
  final List<Widget> actions;
  final String? saveMessage;

  const CompactAppBar({
    super.key,
    required this.isLoading,
    required this.loadingText,
    required this.actions,
    this.saveMessage,
  });

  @override
  @override
  Widget build(BuildContext context) {

    return PreferredSize(
      preferredSize: preferredSize,
      child: AppBar(
        toolbarHeight: 40,
        backgroundColor: Colors.blue[700],
        title: _buildTitle(),
        actions: isLoading ? [] : _buildActions(),
      ),
    );
  }

  Widget _buildTitle() {

    if (saveMessage != null) {
      return _buildTextWithBackground(saveMessage!, Colors.green);
    } else if (isLoading) {
      return _buildTextWithBackground(loadingText, Colors.orange);
    } else {
      return Container();
    }
  }

  Widget _buildTextWithBackground(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  List<Widget> _buildActions() {
    return [
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: actions.map((widget) {
            if (widget is IconButton) {
              return IconButton(
                icon: widget.icon,
                onPressed: widget.onPressed,
                tooltip: widget.tooltip,
                iconSize: 20, // Taille d'icône légèrement augmentée
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }
            return widget;
          }).toList(),
        ),
      ),
    ];
  }

  @override
  Size get preferredSize => const Size.fromHeight(40);
}
