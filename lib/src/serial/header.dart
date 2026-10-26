part of 'serial_terminal.dart';

class MonitorHeader extends StatelessWidget {
  const MonitorHeader({
    super.key,
    required this.type,
    required this.onTypeChanged,
  });

  final MonitorType type;
  final ValueChanged<MonitorType>? onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoSize = 36.0;
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: _rxColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: BackButton(
                    onPressed: () => context.go('/'),
                    color: _rxColor,
                    style: IconButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: max(0, constraints.maxWidth - logoSize - 10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('global.appTitle'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        context.tr('serial.workspace'),
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 150,
              child: SegmentedButton<MonitorType>(
                key: const Key('monitor-type'),
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: MonitorType.normal,
                    label: Text(context.tr('global.normal')),
                  ),
                  ButtonSegment(
                    value: MonitorType.terminal,
                    label: Text(context.tr('global.terminal')),
                  ),
                ],
                selected: {type},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onSelectionChanged: onTypeChanged == null
                    ? null
                    : (selection) => onTypeChanged!(selection.single),
              ),
            ),
          ],
        );
      },
    );
  }
}
