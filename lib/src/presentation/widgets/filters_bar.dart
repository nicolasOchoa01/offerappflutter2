import 'package:flutter/material.dart';

class FiltersBar extends StatelessWidget {
  final String selectedFilter;
  final void Function(String) onFilterChange;
  final String selectedOrder;
  final void Function(String) onOrderChange;

  const FiltersBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChange,
    required this.selectedOrder,
    required this.onOrderChange,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const ['Todos', 'Alimentos', 'Electrodomésticos', 'Moda'];
    final orders = const ['Relevancia', 'Precio ↑', 'Precio ↓'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: filters
                .map((f) => ChoiceChip(
                      label: Text(f),
                      selected: selectedFilter == f,
                      onSelected: (_) => onFilterChange(f),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Ordenar por: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedOrder,
                items: orders
                    .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onOrderChange(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
