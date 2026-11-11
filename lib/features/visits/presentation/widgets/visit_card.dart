import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/visit.dart';

/// Card de visita para el listado.
/// Botones grandes, información clave visible de un vistazo.
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.visit, required this.onTap});

  final Visit visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera: título + badges ──────────────────────────────
              Row(
                children: [
                  _VisitTypeIcon(visitType: visit.visitType),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      visit.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  VisitStatusBadge(status: visit.status),
                ],
              ),

              // ── Cliente ────────────────────────────────────────────────
              if (visit.clientName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      visit.clientName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              // ── Dirección ─────────────────────────────────────────────
              if (visit.address != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        visit.address!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // ── Footer: fecha + sync status ────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppDateUtils.formatRelative(visit.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const Spacer(),
                  SyncStateBadge(status: visit.syncStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitTypeIcon extends StatelessWidget {
  const _VisitTypeIcon({required this.visitType});

  final String visitType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (visitType.toLowerCase()) {
      'energia' => (Icons.bolt_rounded, AppColors.warning),
      'datos' => (Icons.cable_rounded, AppColors.info),
      'general' => (Icons.assignment_rounded, AppColors.primary),
      'ups' => (Icons.battery_charging_full_rounded, AppColors.secondary),
      _ => (Icons.construction_rounded, AppColors.secondary),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
