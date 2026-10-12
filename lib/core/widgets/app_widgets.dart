import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:turkmen_ses/core/theme/app_theme.dart';

/// ---------------------------------------------------------------- containers

class GradientHeader extends StatelessWidget {
  const GradientHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 26),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: padding,
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding = const EdgeInsets.all(18), this.onTap, super.key});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return card;
  }
}

/// ---------------------------------------------------------------- data display

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 15, color: tint),
                ),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class GoalRing extends StatelessWidget {
  const GoalRing({
    required this.progress,
    required this.centerTitle,
    required this.centerSubtitle,
    this.size = 168,
    super.key,
  });

  final double progress;
  final String centerTitle;
  final String centerSubtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(progress: value, track: scheme.outlineVariant, fill: scheme.primary),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    centerTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.fill});

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: <Color>[fill, AppTheme.brandLight],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fill != fill || oldDelegate.track != track;
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({required this.name, this.seed = 0, this.radius = 22, super.key});

  final String name;
  final int seed;
  final double radius;

  static const List<List<Color>> _palette = <List<Color>>[
    <Color>[Color(0xFF0B6E69), Color(0xFF12A594)],
    <Color>[Color(0xFFE76F51), Color(0xFFF4A259)],
    <Color>[Color(0xFF457B9D), Color(0xFF1D3557)],
    <Color>[Color(0xFF6A4C93), Color(0xFFA480CF)],
    <Color>[Color(0xFF2A9D8F), Color(0xFF8AB17D)],
    <Color>[Color(0xFFB5179E), Color(0xFFF72585)],
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'TS';
    }
    if (parts.length == 1) {
      final word = parts.first;
      return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palette[seed.abs() % _palette.length];
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({
    required this.value,
    this.onChanged,
    this.size = 34,
    this.count,
    super.key,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 1; index <= 5; index++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(index),
            child: Padding(
              padding: EdgeInsets.only(right: index == 5 ? 0 : 4),
              child: Icon(
                index <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: index <= value ? AppTheme.accent : scheme.outlineVariant,
              ),
            ),
          ),
        if (count != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class QualityBadge extends StatelessWidget {
  const QualityBadge({required this.score, required this.ratingCount, this.verified = false, super.key});

  final double? score;
  final int ratingCount;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (score == null || ratingCount == 0) {
      return Text(
        'Baha ýok',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.star_rounded, size: 17, color: AppTheme.accent),
        const SizedBox(width: 4),
        Text(
          score!.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        Text(
          '· $ratingCount baha',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (verified) ...<Widget>[
          const SizedBox(width: 6),
          Icon(Icons.verified_rounded, size: 16, color: scheme.primary),
        ],
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final String label;
    late final Color color;
    late final IconData icon;
    switch (status) {
      case 'uploaded':
        label = 'Serwerde';
        color = scheme.primary;
        icon = Icons.cloud_done_rounded;
      case 'approved':
        label = 'Kabul edildi';
        color = const Color(0xFF2E9E6B);
        icon = Icons.verified_rounded;
      case 'rejected':
        label = 'Ret edildi';
        color = AppTheme.danger;
        icon = Icons.cancel_rounded;
      case 'failed':
        label = 'Iberilmedi';
        color = AppTheme.danger;
        icon = Icons.error_outline_rounded;
      case 'uploading':
        label = 'Iberilýär';
        color = AppTheme.accent;
        icon = Icons.cloud_upload_rounded;
      default:
        label = 'Nobatda';
        color = AppTheme.accent;
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------- feedback

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...<Widget>[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Baglanyşyk meselesi',
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Täzeden synanyş'),
            ),
    );
  }
}

/// ---------------------------------------------------------------- recording

/// Live amplitude bars — `values` are 0..1 loudness samples.
class LiveWaveform extends StatelessWidget {
  const LiveWaveform({required this.values, this.color, this.height = 72, super.key});

  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(values: values, color: tint),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    final count = values.isEmpty ? 1 : values.length;
    final step = size.width / count;
    final middle = size.height / 2;
    for (int index = 0; index < count; index++) {
      final value = values.isEmpty ? 0.05 : values[index].clamp(0.04, 1.0);
      final barHeight = value * (size.height * 0.86);
      final x = step * index + step / 2;
      canvas.drawLine(
        Offset(x, middle - barHeight / 2),
        Offset(x, middle + barHeight / 2),
        paint..color = color.withValues(alpha: 0.35 + 0.65 * value),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => oldDelegate.values != values;
}

class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    required this.recording,
    required this.onTap,
    this.diameter = 108,
    super.key,
  });

  final bool recording;
  final VoidCallback onTap;
  final double diameter;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.recording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.recording && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.diameter * 1.6,
      height: widget.diameter * 1.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (widget.recording)
                for (final double offset in <double>[0, 0.33, 0.66])
                  _ripple(scheme.primary, (_controller.value + offset) % 1.0),
              child!,
            ],
          );
        },
        child: Material(
          color: widget.recording ? AppTheme.danger : scheme.primary,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: SizedBox(
              width: widget.diameter,
              height: widget.diameter,
              child: Icon(
                widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                size: widget.diameter * 0.44,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ripple(Color color, double progress) {
    return Container(
      width: widget.diameter + (widget.diameter * 1.2 * progress),
      height: widget.diameter + (widget.diameter * 1.2 * progress),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18 * (1 - progress)),
      ),
    );
  }
}

class ServerStatusBanner extends StatelessWidget {
  const ServerStatusBanner({required this.online, this.message, this.onTap, super.key});

  final bool online;
  final String? message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = online ? scheme.primary : AppTheme.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ??
                    (online
                        ? 'Serwer bilen baglanyşyk bar — ýazgylar iberilip bilner.'
                        : 'Internet ýok. Ýazgylar telefonda nobatda saklanýar.'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (onTap != null) Icon(Icons.refresh_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
