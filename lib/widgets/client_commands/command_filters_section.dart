import 'package:flutter/material.dart';

class CommandFiltersSection extends StatelessWidget {
  final bool isFr;
  final TextEditingController searchController;
  final String selectedPlatform;
  final String selectedCategory;
  final bool showOnlyElevated;
  final List<String> categories;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool?> onElevationChanged;
  final VoidCallback onSearchClear;

  const CommandFiltersSection({
    super.key,
    required this.isFr,
    required this.searchController,
    required this.selectedPlatform,
    required this.selectedCategory,
    required this.showOnlyElevated,
    required this.categories,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onElevationChanged,
    required this.onSearchClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText:
                  isFr ? 'Rechercher une commande...' : 'Search command...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onSearchClear,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          const SizedBox(height: 12),

          // Filtres
          Row(
            children: [
              // Sélecteur de plateforme
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPlatform,
                  decoration: InputDecoration(
                    labelText: isFr ? 'Plateforme' : 'Platform',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  items: ['Windows', 'Linux'].map((platform) {
                    return DropdownMenuItem(
                      value: platform,
                      child: Row(
                        children: [
                          Icon(
                            platform == 'Windows'
                                ? Icons.computer
                                : Icons.terminal,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(platform),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: onPlatformChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Sélecteur de catégorie
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: isFr ? 'Catégorie' : 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filtre élévation
          CheckboxListTile(
            title: Text(
              isFr
                  ? 'Commandes privilégiées uniquement'
                  : 'Elevated commands only',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              isFr
                  ? 'Nécessitent des droits administrateur'
                  : 'Require administrator rights',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: showOnlyElevated,
            onChanged: onElevationChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
