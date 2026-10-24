part of 'monitor_screen.dart';

class MonitorHeader extends StatelessWidget {
  const MonitorHeader({
    super.key,
    this.compact = true,
    required this.type,
    required this.onTypeChanged,
  });

  final bool compact;
  final MonitorType type;
  final ValueChanged<MonitorType>? onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoSize = compact ? 36.0 : 46.0;
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
                  child: Navigator.of(context).canPop()
                      ? BackButton(
                          color: _rxColor,
                          style: IconButton.styleFrom(padding: EdgeInsets.zero),
                        )
                      : Icon(
                          Icons.terminal_rounded,
                          color: _rxColor,
                          size: compact ? 22 : 26,
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
                        'Serial Terminal',
                        style: TextStyle(
                          fontSize: compact ? 20 : 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        'Linux · Seri port çalışma alanı',
                        style: TextStyle(
                          color: _muted,
                          fontSize: compact ? 11 : 12,
                        ),
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
                segments: const [
                  ButtonSegment(
                    value: MonitorType.normal,
                    label: Text('Normal'),
                  ),
                  ButtonSegment(
                    value: MonitorType.terminal,
                    label: Text('Terminal'),
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
