import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estado del registro (sello) reutilizable en dosis y atenciones.
enum StatusTone { applied, cancelled, draft, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    this.tone = StatusTone.neutral,
    super.key,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.applied => (AppColors.successSoft, AppColors.success),
      StatusTone.cancelled => (AppColors.dangerSoft, AppColors.danger),
      StatusTone.draft => (AppColors.warningSoft, AppColors.warning),
      StatusTone.neutral => (AppColors.surfaceAlt, AppColors.slate),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: fg, fontSize: 10),
      ),
    );
  }
}

/// Encabezado de seccion con indice tipo folio ("01 · Datos basicos").
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.index,
    required this.title,
    this.subtitle,
    super.key,
  });

  final String index;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          index,
          style: AppTextStyles.overline.copyWith(color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.hint, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Franja de identidad: documento en cifras tabulares para verificacion rapida.
class IdentityStrip extends StatelessWidget {
  const IdentityStrip({
    required this.documentType,
    required this.documentNumber,
    this.name,
    this.trailing,
    super.key,
  });

  final String documentType;
  final String documentNumber;
  final String? name;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.badge_outlined,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$documentType · $documentNumber',
                style: AppTextStyles.figure.copyWith(
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
              if (name != null && name!.isNotEmpty)
                Text(
                  name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Estado vacio con jerarquia (icono contenido + titulo + guia).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.hint, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.hint,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Texto en cifras tabulares (documentos, lotes, fechas).
class MonoText extends StatelessWidget {
  const MonoText(this.text, {this.style, this.muted = false, super.key});

  final String text;
  final TextStyle? style;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final base = (muted ? AppTextStyles.figureMuted : AppTextStyles.figure)
        .copyWith(color: muted ? AppColors.slate : AppColors.ink);
    return Text(text, style: base.merge(style));
  }
}
