import 'package:flutter/material.dart';

extension BlueDialogExtension on BuildContext {
  Future<T?> blueDialog<T>({
    required Widget child,
    required Text title,
    Text? subtitle,
    BoxConstraints constraints = const BoxConstraints(
      maxWidth: 560,
      maxHeight: 640,
    ),
    Alignment alignment = Alignment.center,
    EdgeInsets margin = EdgeInsets.zero,
    EdgeInsets padding = const EdgeInsets.all(24),
    BoxDecoration? decoration,
    Widget icon = const Icon(Icons.info_outline_rounded, size: 22),
    Icon closeIcon = const Icon(Icons.close_rounded, size: 20),
    Widget? divider,
  }) {
    return showDialog<T>(
      context: this,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Dialog(
          alignment: alignment,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          constraints: constraints,
          child: Container(
            width: double.infinity,
            margin: margin,
            padding: padding,
            decoration:
                decoration ??
                BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: colors.primary),
                        child: icon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle(
                            style: theme.textTheme.titleLarge!,
                            child: title,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            DefaultTextStyle(
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              child: subtitle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                      icon: closeIcon,
                    ),
                  ],
                ),
                divider ?? Divider(height: 32, color: colors.outlineVariant),
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
