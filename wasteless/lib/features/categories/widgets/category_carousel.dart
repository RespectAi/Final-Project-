import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CategoryCarousel extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> allCategories;
  final String? selectedCatId;
  final int Function(String? catId) getItemCountForCategory;
  final void Function(String? id, String? name) onSelectCategory;

  const CategoryCarousel({
    super.key,
    required this.scrollController,
    required this.allCategories,
    required this.selectedCatId,
    required this.getItemCountForCategory,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final allCount = getItemCountForCategory(null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with scroll indicator cue for mobile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'CATEGORIES (${allCategories.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swipe for more',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey[500]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Horizontal Swipeable Category Carousel
        SizedBox(
          height: 44,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length + 1, // +1 for "All Items"
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All Items" Chip
                final isSelected = selectedCatId == null;
                return _buildCategoryPill(
                  id: null,
                  name: 'All Items',
                  iconUrl: null,
                  itemCount: allCount,
                  isSelected: isSelected,
                  fallbackIcon: Icons.grid_view_rounded,
                );
              }

              final cat = allCategories[index - 1];
              final id = cat['id']?.toString() ?? '';
              final name = (cat['name'] as String?) ?? 'Category';
              final iconUrl = (cat['icon_url'] as String?) ?? '';
              final isSelected = selectedCatId == id;
              final count = getItemCountForCategory(id);

              return _buildCategoryPill(
                id: id,
                name: name,
                iconUrl: iconUrl,
                itemCount: count,
                isSelected: isSelected,
                fallbackIcon: Icons.eco_outlined,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill({
    required String? id,
    required String name,
    required String? iconUrl,
    required int itemCount,
    required bool isSelected,
    required IconData fallbackIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (isSelected && id != null) {
              onSelectCategory(null, null);
            } else {
              onSelectCategory(id, name);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.gradientStart, Color(0xFF00B074)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.gradientStart.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconUrl != null && iconUrl.isNotEmpty)
                  Image.network(
                    iconUrl,
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) => Icon(
                      fallbackIcon,
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.gradientStart,
                    ),
                  )
                else
                  Icon(
                    fallbackIcon,
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.gradientStart,
                  ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$itemCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
