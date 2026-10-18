import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_colors.dart';

/// Selector de perfil tipo segmented control: Público | DJ.
class RoleSegmentedControl extends StatelessWidget {
  const RoleSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: UserRole.values.map((rol) {
          final selected = rol == value;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected ? AppColors.limeGreen : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(rol),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      rol.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? AppColors.onLime : AppColors.muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
