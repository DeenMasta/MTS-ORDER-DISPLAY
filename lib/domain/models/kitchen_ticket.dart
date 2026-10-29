class KitchenTicketItem {
  const KitchenTicketItem({
    required this.name,
    required this.quantity,
    this.comments,
  });

  final String name;
  final num quantity;
  final String? comments;

  factory KitchenTicketItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final quantity = json['quantity'];
    if (name is! String || name.trim().isEmpty || quantity is! num) {
      throw const FormatException('Invalid kitchen order item.');
    }
    return KitchenTicketItem(
      name: name,
      quantity: quantity,
      comments: json['comments'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'comments': comments,
  };
}

class KitchenTicket {
  const KitchenTicket({
    required this.messageId,
    required this.saleId,
    required this.departmentId,
    required this.revision,
    required this.action,
    required this.orderNumber,
    required this.createdAt,
    required this.items,
    this.tableName,
    this.orderName,
    this.remarks,
  });

  final String messageId;
  final String saleId;
  final String departmentId;
  final int revision;
  final String action;
  final String orderNumber;
  final DateTime createdAt;
  final List<KitchenTicketItem> items;
  final String? tableName;
  final String? orderName;
  final String? remarks;

  String get id => '$saleId:$departmentId';

  factory KitchenTicket.fromJson(Map<String, dynamic> json) {
    String value(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing kitchen order field: $key');
      }
      return value;
    }

    final revision = json['revision'];
    final orderNumber = json['order_number'];
    final createdAt = DateTime.tryParse(value('created_at'));
    final items = json['items'];
    final action = value('action');
    if (revision is! int || revision < 1 || orderNumber is! int || createdAt == null || items is! List || !{'upsert', 'cancel'}.contains(action)) {
      throw const FormatException('Invalid kitchen order.');
    }
    return KitchenTicket(
      messageId: value('message_id'),
      saleId: value('sale_id'),
      departmentId: value('department_id'),
      revision: revision,
      action: action,
      orderNumber: orderNumber.toString(),
      createdAt: createdAt,
      items: items.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid kitchen order item.');
        }
        return KitchenTicketItem.fromJson(item);
      }).toList(growable: false),
      tableName: json['table_name'] as String?,
      orderName: json['order_name'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'sale_id': saleId,
    'department_id': departmentId,
    'revision': revision,
    'action': action,
    'order_number': int.tryParse(orderNumber) ?? orderNumber,
    'table_name': tableName,
    'order_name': orderName,
    'remarks': remarks,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}
