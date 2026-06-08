/// Adaptive single-tap context menu widgets and models for iOS and Flutter fallback platforms.
library ios_single_tap_context_menu;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:svg_flutter/svg.dart';

/// Base type for all context menu entries.
@immutable
abstract class IosContextMenuItem {
  /// Creates a menu entry.
  const IosContextMenuItem();
}

/// Visual separator between action groups.
@immutable
class IosContextMenuDivider extends IosContextMenuItem {
  /// Creates a divider item.
  const IosContextMenuDivider({
    this.color,
  });

  /// Divider color used by Flutter fallback menus.
  ///
  /// Native iOS menus ignore this and use UIKit's system divider styling.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is IosContextMenuDivider && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

/// Nested menu entry that opens a child list of items.
@immutable
class IosContextMenuSubmenu extends IosContextMenuItem {
  /// Creates a submenu entry.
  const IosContextMenuSubmenu({
    required this.title,
    required this.children,
    this.icon,
    this.iconSystemName,
    this.iconAssetPath,
  });

  /// Label shown for this submenu.
  final String title;

  /// Flutter icon used by fallback menus on Android, web, and desktop.
  final IconData? icon;

  /// SF Symbol name used on iOS when provided.
  final String? iconSystemName;

  /// Asset path for an icon image.
  final String? iconAssetPath;

  /// Child items shown when the submenu opens.
  final List<IosContextMenuItem> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is IosContextMenuSubmenu &&
        other.title == title &&
        other.icon == icon &&
        other.iconSystemName == iconSystemName &&
        other.iconAssetPath == iconAssetPath &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
        title,
        icon,
        iconSystemName,
        iconAssetPath,
        Object.hashAll(children),
      );
}

/// Tappable action in the context menu.
@immutable
class IosContextMenuAction extends IosContextMenuItem {
  /// Creates an action entry.
  const IosContextMenuAction({
    required this.id,
    required this.title,
    this.icon,
    this.iconSystemName,
    this.iconAssetPath,
    this.showTrailingCheckmark = false,
    this.destructive = false,
    this.enabled = true,
  });

  /// Unique action identifier returned in [IosSingleTapContextMenu.onSelected].
  final String id;

  /// Label shown to the user.
  final String title;

  /// Flutter icon used by fallback menus on Android, web, and desktop.
  final IconData? icon;

  /// SF Symbol name used on iOS when provided.
  final String? iconSystemName;

  /// Asset path for an icon image.
  final String? iconAssetPath;

  /// Whether to show a trailing checkmark.
  final bool showTrailingCheckmark;

  /// Marks this action as destructive.
  final bool destructive;

  /// Whether this action can be selected.
  final bool enabled;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is IosContextMenuAction &&
        other.id == id &&
        other.title == title &&
        other.icon == icon &&
        other.iconSystemName == iconSystemName &&
        other.iconAssetPath == iconAssetPath &&
        other.showTrailingCheckmark == showTrailingCheckmark &&
        other.destructive == destructive &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        icon,
        iconSystemName,
        iconAssetPath,
        showTrailingCheckmark,
        destructive,
        enabled,
      );
}

/// Single-tap adaptive context menu widget.
///
/// On iOS it presents native `UIMenu`. On Android, web, and desktop it shows
/// a Material popup menu while keeping the same action model.
class IosSingleTapContextMenu extends StatefulWidget {
  /// Creates a single-tap context menu host.
  const IosSingleTapContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.onSelected,
    this.fallbackMenuMinWidth = 202,
  });

  /// Child widget that triggers the menu.
  final Widget child;

  /// Menu items shown when the user taps [child].
  final List<IosContextMenuItem> actions;

  /// Callback invoked with selected [IosContextMenuAction.id].
  final ValueChanged<String>? onSelected;

  /// Minimum width for the Flutter fallback popup menu.
  ///
  /// Native iOS menus ignore this and size according to UIKit.
  final double fallbackMenuMinWidth;

  @override
  State<IosSingleTapContextMenu> createState() =>
      _IosSingleTapContextMenuState();
}

class _IosSingleTapContextMenuState extends State<IosSingleTapContextMenu> {
  static const int _targetIconPx = 36;
  static const MethodChannel _iosHostChannel =
      MethodChannel('ios_adaptive_context_menu/methods');

  final Map<String, Uint8List?> _iconBytesCache = <String, Uint8List?>{};
  late final String _instanceId;
  late final MethodChannel _iosInstanceChannel;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _instanceId =
        '${identityHashCode(this)}_${DateTime.now().microsecondsSinceEpoch}';
    _iosInstanceChannel = MethodChannel(
      'ios_adaptive_context_menu/instance_$_instanceId',
    );
    _iosInstanceChannel.setMethodCallHandler(_handleCallback);
  }

  @override
  void dispose() {
    if (_isIos) {
      _iosHostChannel.invokeMethod<void>('disposeInstance', {
        'instanceId': _instanceId,
      });
    }
    _iosInstanceChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) {
      return widget.child;
    }

    if (_isIos) {
      return _buildIosHost();
    }

    return _buildFlutterFallbackHost();
  }

  Widget _buildIosHost() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 1,
      onPressed: _showIosMenu,
      child: AbsorbPointer(child: widget.child),
    );
  }

  Future<void> _showIosMenu() async {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final Rect anchorRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final params = await _buildCreationParams();
    params['instanceId'] = _instanceId;
    params['x'] = anchorRect.left;
    params['y'] = anchorRect.top;
    params['width'] = anchorRect.width;
    params['height'] = anchorRect.height;

    await _iosHostChannel.invokeMethod<void>('showMenu', params);
  }

  Widget _buildFlutterFallbackHost() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _showFlutterFallbackMenu,
      child: widget.child,
    );
  }

  Future<void> _showFlutterFallbackMenu(TapDownDetails details) async {
    final selectedId = await _showFlutterFallbackMenuForItems(
      context: context,
      position: details.globalPosition,
      items: widget.actions,
    );

    if (selectedId != null && widget.onSelected != null) {
      widget.onSelected!(selectedId);
    }
  }

  Future<String?> _showFlutterFallbackMenuForItems({
    required BuildContext context,
    required Offset position,
    required List<IosContextMenuItem> items,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final menuItems = _buildFlutterFallbackPopupEntries(items);

    if (menuItems.isEmpty) {
      return null;
    }

    final selected = await showMenu<_FallbackMenuResult>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );

    if (selected == null) {
      return null;
    }

    return selected.actionId;
  }

  List<PopupMenuEntry<_FallbackMenuResult>> _buildFlutterFallbackPopupEntries(
    List<IosContextMenuItem> items,
  ) {
    final entries = <PopupMenuEntry<_FallbackMenuResult>>[];
    final dividerColor = Theme.of(context).dividerColor;
    final flatItems = _flattenForFallback(items);

    void addDividerIfNeeded(IosContextMenuDivider divider) {
      if (entries.isEmpty || entries.last is _FallbackPopupDivider) {
        return;
      }
      entries.add(
        _FallbackPopupDivider(
          color: divider.color ?? dividerColor,
          height: 10,
          thickness: 1,
          horizontalPadding: 10,
        ),
      );
    }

    for (final item in flatItems) {
      if (item is IosContextMenuDivider) {
        addDividerIfNeeded(item);
        continue;
      }

      if (item is IosContextMenuAction) {
        entries.add(
          PopupMenuItem<_FallbackMenuResult>(
            enabled: item.enabled,
            value: _FallbackMenuResult.action(item.id),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: widget.fallbackMenuMinWidth),
              child: Row(
                children: [
                  _buildFlutterFallbackMenuIcon(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: item.destructive
                          ? const TextStyle(color: Colors.red)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    while (entries.isNotEmpty && entries.last is _FallbackPopupDivider) {
      entries.removeLast();
    }

    return entries;
  }

  List<IosContextMenuItem> _flattenForFallback(List<IosContextMenuItem> items) {
    final result = <IosContextMenuItem>[];
    for (final item in items) {
      if (item is IosContextMenuSubmenu) {
        result.addAll(_flattenForFallback(item.children));
      } else {
        result.add(item);
      }
    }
    return result;
  }

  Widget _buildFlutterFallbackMenuIcon(IosContextMenuAction item) {
    if (item.icon != null) {
      return Icon(item.icon, size: 20);
    }

    final assetPath = item.iconAssetPath;
    if (assetPath != null && assetPath.isNotEmpty) {
      return SvgPicture.asset(
        assetPath,
        width: 20,
        height: 20,
      );
    }

    return const SizedBox(width: 20, height: 20);
  }

  Future<Map<String, Object?>> _buildCreationParams() async {
    final serialized = <Map<String, Object?>>[];
    for (final item in widget.actions) {
      serialized.add(await _serializeItem(item));
    }
    return <String, Object?>{'actions': serialized};
  }

  Future<Map<String, Object?>> _serializeItem(IosContextMenuItem item) async {
    if (item is IosContextMenuDivider) {
      return const <String, Object?>{'type': 'divider'};
    }

    if (item is IosContextMenuAction) {
      return _serializeAction(item);
    }

    if (item is IosContextMenuSubmenu) {
      return _serializeSubmenu(item);
    }

    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _serializeAction(
      IosContextMenuAction action) async {
    final map = <String, Object?>{
      'type': 'action',
      'id': action.id,
      'title': action.title,
      'iconSystemName': action.iconSystemName,
      'showTrailingCheckmark': action.showTrailingCheckmark,
      'destructive': action.destructive,
      'enabled': action.enabled,
    };

    if (action.iconSystemName == null || action.iconSystemName!.isEmpty) {
      await _attachIconBytes(map, action.iconAssetPath);
    }
    return map;
  }

  Future<Map<String, Object?>> _serializeSubmenu(
      IosContextMenuSubmenu submenu) async {
    final children = <Map<String, Object?>>[];
    for (final item in submenu.children) {
      children.add(await _serializeItem(item));
    }

    final map = <String, Object?>{
      'type': 'submenu',
      'title': submenu.title,
      'iconSystemName': submenu.iconSystemName,
      'children': children,
    };

    if (submenu.iconSystemName == null || submenu.iconSystemName!.isEmpty) {
      await _attachIconBytes(map, submenu.iconAssetPath);
    }
    return map;
  }

  Future<void> _attachIconBytes(
      Map<String, Object?> map, String? iconAssetPath) async {
    if (iconAssetPath == null || iconAssetPath.isEmpty) {
      return;
    }

    final iconBytes = await _resolveIconBytes(iconAssetPath);
    if (iconBytes != null && iconBytes.isNotEmpty) {
      map['iconPngBytes'] = iconBytes;
    }
  }

  Future<Uint8List?> _resolveIconBytes(String assetPath) async {
    if (_iconBytesCache.containsKey(assetPath)) {
      return _iconBytesCache[assetPath];
    }

    try {
      if (_isSvg(assetPath)) {
        final bytes = await _rasterizeSvgToPng(assetPath);
        _iconBytesCache[assetPath] = bytes;
        return bytes;
      }

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      _iconBytesCache[assetPath] = bytes;
      return bytes;
    } catch (_) {
      _iconBytesCache[assetPath] = null;
      return null;
    }
  }

  bool _isSvg(String path) => path.toLowerCase().endsWith('.svg');

  Future<Uint8List?> _rasterizeSvgToPng(String assetPath) async {
    final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);
    final sourceSize = pictureInfo.size;

    final sourceWidth = sourceSize.width > 0 && sourceSize.width.isFinite
        ? sourceSize.width
        : _targetIconPx.toDouble();
    final sourceHeight = sourceSize.height > 0 && sourceSize.height.isFinite
        ? sourceSize.height
        : _targetIconPx.toDouble();

    final scale = _targetIconPx / math.max(sourceWidth, sourceHeight);
    final outWidth = (sourceWidth * scale).round().clamp(18, 72);
    final outHeight = (sourceHeight * scale).round().clamp(18, 72);

    final ui.Image image =
        await pictureInfo.picture.toImage(outWidth, outHeight);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    pictureInfo.picture.dispose();

    return byteData?.buffer.asUint8List();
  }

  Future<void> _handleCallback(MethodCall call) async {
    if (call.method != 'onSelected' || widget.onSelected == null) {
      return;
    }

    final Object? args = call.arguments;
    if (args is! Map<Object?, Object?>) {
      return;
    }

    final Object? rawId = args['id'];
    if (rawId is String && rawId.isNotEmpty) {
      widget.onSelected!.call(rawId);
    }
  }
}

@immutable
class _FallbackMenuResult {
  const _FallbackMenuResult._({this.actionId});

  const _FallbackMenuResult.action(String id) : this._(actionId: id);

  final String? actionId;
}

class _FallbackPopupDivider extends PopupMenuEntry<_FallbackMenuResult> {
  const _FallbackPopupDivider({
    required this.color,
    required this.height,
    required this.thickness,
    required this.horizontalPadding,
  });

  final Color color;
  final double thickness;
  final double horizontalPadding;

  @override
  final double height;

  @override
  bool represents(_FallbackMenuResult? value) => false;

  @override
  State<_FallbackPopupDivider> createState() => _FallbackPopupDividerState();
}

class _FallbackPopupDividerState extends State<_FallbackPopupDivider> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: widget.thickness,
            width: double.infinity,
            child: CustomPaint(
              painter: _FallbackDividerPainter(
                color: widget.color,
                strokeWidth: widget.thickness,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackDividerPainter extends CustomPainter {
  const _FallbackDividerPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final y = strokeWidth / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _FallbackDividerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
