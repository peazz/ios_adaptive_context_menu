import 'package:flutter/material.dart';
import 'package:ios_adaptive_context_menu/ios_adaptive_context_menu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ios_adaptive_context_menu example',
      home: const ContextMenuExamplePage(),
    );
  }
}

class ContextMenuExamplePage extends StatefulWidget {
  const ContextMenuExamplePage({super.key});

  @override
  State<ContextMenuExamplePage> createState() => _ContextMenuExamplePageState();
}

class _ContextMenuExamplePageState extends State<ContextMenuExamplePage> {
  String _selectedId = 'none';

  List<IosContextMenuItem> get _actions => <IosContextMenuItem>[
        const IosContextMenuSubmenu(
          title: 'Share',
          icon: Icons.share_outlined,
          iconSystemName: 'square.and.arrow.up',
          iconAssetPath: MediaRes.share,
          children: <IosContextMenuItem>[
            IosContextMenuAction(
              id: 'share_meal',
              title: 'Share meal',
              icon: Icons.share_outlined,
              iconSystemName: 'square.and.arrow.up',
              iconAssetPath: MediaRes.share,
            ),
          ],
        ),
        const IosContextMenuDivider(),
        const IosContextMenuAction(
          id: 'saveasrecipe',
          title: 'Save as recipe',
          icon: Icons.book_outlined,
          iconSystemName: 'book.closed',
          iconAssetPath: MediaRes.share,
        ),
        const IosContextMenuDivider(),
        const IosContextMenuAction(
          id: 'clr',
          title: 'Clear meal',
          destructive: true,
          icon: Icons.delete_outline,
          iconSystemName: 'trash',
          iconAssetPath: MediaRes.share,
        ),
        const IosContextMenuAction(
          id: 'rpt',
          title: 'Repeat meal',
          icon: Icons.repeat,
          iconSystemName: 'repeat',
          iconAssetPath: MediaRes.share,
        ),
        const IosContextMenuAction(
          id: 'pst',
          title: 'Paste',
          icon: Icons.content_paste,
          iconSystemName: 'document.on.clipboard',
          iconAssetPath: MediaRes.share,
        ),
        const IosContextMenuAction(
          id: 'cp',
          title: 'Copy',
          icon: Icons.copy,
          iconSystemName: 'pip',
          iconAssetPath: MediaRes.share,
        ),
      ];

  TextStyle appStyle({
    required Color color,
    required FontWeight fw,
    required double size,
  }) {
    return TextStyle(color: color, fontWeight: fw, fontSize: size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Single Tap Context Menu')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IosSingleTapContextMenu(
              actions: _actions,
              onSelected: (String id) {
                setState(() {
                  _selectedId = id;
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Selected action: $id')));
              },
              child: Text(
                'Open Context Menu',
                style: appStyle(
                  color: Colors.black,
                  fw: FontWeight.bold,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Last selected action: $_selectedId'),
          ],
        ),
      ),
    );
  }
}

class MediaRes {
  const MediaRes._();

  static const String share = 'assets/share.svg';
}
