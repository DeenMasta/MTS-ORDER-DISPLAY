class KitchenTicketItem {
  const KitchenTicketItem({
    required this.name,
    required this.quantity,
    this.comments,
    this.variant,
    this.modifiers = const [],
  });

  final String name;
  final num quantity;
  final String? comments;
  final String? variant;
  final List<String> modifiers;

  String get displayQuantity => quantity == quantity.truncate()
      ? quantity.truncate().toString()
      : quantity.toString();

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
      variant: json['variant'] as String?,
      modifiers: (json['modifiers'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'comments': comments,
    'variant': variant,
    'modifiers': modifiers,
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
    this.orderTypeId,
    this.orderTypeName,
    this.staffName,
    this.orderedBy,
    this.orderFor,
    this.enteredAt,
    this.orderTypes = const [],
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
  final String? orderTypeId;
  final String? orderTypeName;
  final String? staffName;
  final String? orderedBy;
  final String? orderFor;
  final DateTime? enteredAt;
  final List<KdsOrderType> orderTypes;

  String get id => '$saleId:$departmentId';

  String? get displayOrderer {
    final orderedBy = this.orderedBy?.trim();
    if (orderedBy?.isNotEmpty ?? false) return orderedBy;
    return orderName?.trim();
  }

  String? get displayRemarks {
    final remarks = this.remarks?.trim();
    if (remarks == null || remarks.isEmpty || remarks == '0003642759') {
      return null;
    }
    return remarks;
  }

  static String? _optionalString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

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
    if (revision is! int ||
        revision < 1 ||
        orderNumber is! int ||
        createdAt == null ||
        items is! List ||
        !{'upsert', 'cancel'}.contains(action)) {
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
      items: items
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid kitchen order item.');
            }
            return KitchenTicketItem.fromJson(item);
          })
          .toList(growable: false),
      tableName: json['table_name'] as String?,
      orderName: json['order_name'] as String?,
      remarks: json['remarks'] as String?,
      orderTypeId: (json['order_type'] as Map?)?['id'] as String?,
      orderTypeName: (json['order_type'] as Map?)?['name'] as String?,
      staffName: _optionalString(json['staff_name']) ??
          _optionalString(json['staff']),
      orderedBy: json['ordered_by'] as String?,
      orderFor: json['order_for'] as String?,
      enteredAt: DateTime.tryParse(json['entered_at'] as String? ?? ''),
      orderTypes: (json['order_types'] as List? ?? const [])
          .whereType<Map>()
          .map((type) => KdsOrderType.fromJson(Map<String, dynamic>.from(type)))
          .toList(growable: false),
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
    'order_type': {'id': orderTypeId, 'name': orderTypeName},
    'staff_name': staffName,
    'ordered_by': orderedBy,
    'order_for': orderFor,
    'entered_at': enteredAt?.toIso8601String(),
    'order_types': orderTypes
        .map((type) => type.toJson())
        .toList(growable: false),
    'created_at': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

class KdsOrderType {
  const KdsOrderType({
    required this.id,
    required this.name,
    this.icon = 'restaurant',
  });
  final String id;
  final String name;
  final String icon;
  factory KdsOrderType.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String || id.isEmpty || name.isEmpty) {
      throw const FormatException('Invalid order type.');
    }
    return KdsOrderType(
      id: id,
      name: name,
      icon: json['icon'] as String? ?? 'restaurant',
    );
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon};
}

/// Groups one sale's department tickets into the single order card shown on KDS.
List<List<KitchenTicket>> groupKitchenTicketsByOrder(
  Iterable<KitchenTicket> tickets,
) {
  final groups = <String, List<KitchenTicket>>{};
  for (final ticket in tickets) {
    groups
        .putIfAbsent(
          '${ticket.saleId}:${ticket.orderNumber}',
          () => <KitchenTicket>[],
        )
        .add(ticket);
  }
  return groups.values.toList(growable: false);
}
