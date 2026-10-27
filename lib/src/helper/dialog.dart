import 'package:flutter/material.dart';
extension BlueDialogExtension on BuildContext {
  Future<T?> blueDialog<T>({
    required Widget child,
    required Text title,
    Text? subtitle,
    BoxConstraints constraints =  const BoxConstraints(
      minWidth: 400,
      minHeight: 400,
      maxWidth: 500,
      maxHeight: 500,
    ),
    Alignment alignment = Alignment.bottomCenter,
    EdgeInsets margin = const EdgeInsets.all(0),
    EdgeInsets padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    BoxDecoration? decoration,
    Widget icon = const Icon(
      Icons.info,
      color: Color(0xFF20D99B),
      size: 16,
    ),
    Icon closeIcon = const Icon(
      Icons.close_rounded,
      color: Color(0xFFE05260),
      size: 20,
    ),
    Widget divider = const SizedBox(height: 14,)
  }) {
    return showDialog<T>(
      context: this,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          alignment:  alignment,
          insetPadding: const EdgeInsets.all(0),
          backgroundColor: Colors.transparent,
          constraints: constraints,
          child: Container(
            margin: margin,
            padding: padding,
            decoration: decoration,
            child: Column(
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          if (subtitle != null)
                            subtitle,
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(.04),
                        minimumSize: const Size(34, 34),
                      ),
                      icon: closeIcon,
                    ),
                  ],
                ),
                divider,
                Expanded(child: child)
              ],
            ),
          ),
        );
      },
    );
  }
}