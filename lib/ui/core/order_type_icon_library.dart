import 'package:flutter/material.dart';

/// The common icon catalogue used by the order-type Settings and receipts.
///
/// Keeping the choices and their icon mapping in one place makes an icon
/// selected in Settings render the same way everywhere in the KDS.
class OrderTypeIconOption {
  const OrderTypeIconOption({
    required this.category,
    required this.name,
    required this.label,
    required this.icon,
  });

  final String category;
  final String name;
  final String label;
  final IconData icon;
}

const orderTypeIconLibrary = <OrderTypeIconOption>[
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'restaurant',
    label: 'Restaurant',
    icon: Icons.restaurant,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'table_restaurant',
    label: 'Table service',
    icon: Icons.table_restaurant,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'takeout_dining',
    label: 'Takeaway',
    icon: Icons.takeout_dining,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'delivery_dining',
    label: 'Food delivery',
    icon: Icons.delivery_dining,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'local_cafe',
    label: 'Cafe',
    icon: Icons.local_cafe,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'fastfood',
    label: 'Fast food',
    icon: Icons.fastfood,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'bakery_dining',
    label: 'Bakery',
    icon: Icons.bakery_dining,
  ),
  OrderTypeIconOption(
    category: 'Food & beverage',
    name: 'icecream',
    label: 'Dessert',
    icon: Icons.icecream,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'store',
    label: 'Store',
    icon: Icons.store,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'shopping_bag',
    label: 'Shopping bag',
    icon: Icons.shopping_bag,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'shopping_cart',
    label: 'Shopping cart',
    icon: Icons.shopping_cart,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'local_mall',
    label: 'Mall',
    icon: Icons.local_mall,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'inventory_2',
    label: 'Inventory',
    icon: Icons.inventory_2,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'local_grocery_store',
    label: 'Groceries',
    icon: Icons.local_grocery_store,
  ),
  OrderTypeIconOption(
    category: 'Retail',
    name: 'sell',
    label: 'Sale tag',
    icon: Icons.sell,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'room_service',
    label: 'Room service',
    icon: Icons.room_service,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'directions_car',
    label: 'Transport',
    icon: Icons.directions_car,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'cleaning_services',
    label: 'Cleaning',
    icon: Icons.cleaning_services,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'content_cut',
    label: 'Salon',
    icon: Icons.content_cut,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'handyman',
    label: 'Repair',
    icon: Icons.handyman,
  ),
  OrderTypeIconOption(
    category: 'Service',
    name: 'support_agent',
    label: 'Customer service',
    icon: Icons.support_agent,
  ),
];

OrderTypeIconOption orderTypeIconOptionFor(String name) =>
    orderTypeIconLibrary.firstWhere(
      (option) => option.name == name,
      orElse: () => orderTypeIconLibrary.first,
    );

IconData orderTypeIconFor(String name) => orderTypeIconOptionFor(name).icon;
