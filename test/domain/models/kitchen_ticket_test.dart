import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';

void main() {
  test('parses a POS kitchen order', () {
    final ticket = KitchenTicket.fromJson({
      'message_id': 'message-1',
      'sale_id': 'sale-1',
      'department_id': 'department-1',
      'revision': 2,
      'action': 'upsert',
      'order_number': 104,
      'staff_name': 'Syad',
      'remarks': '0003642759',
      'created_at': '2026-10-29T10:30:00+08:00',
      'items': [
        {'name': 'Chicken Rice', 'quantity': 2, 'comments': 'No chilli'},
      ],
    });

    expect(ticket.id, 'sale-1:department-1');
    expect(ticket.revision, 2);
    expect(ticket.items.single.name, 'Chicken Rice');
    expect(ticket.staffName, 'Syad');
    expect(ticket.displayRemarks, isNull);
  });

  test('uses the POS order name when ordered by is unavailable', () {
    final ticket = KitchenTicket.fromJson({
      'message_id': 'message-2',
      'sale_id': 'sale-1',
      'department_id': 'department-1',
      'revision': 1,
      'action': 'upsert',
      'order_number': 105,
      'order_name': 'Ahmad',
      'remarks': 'No chilli',
      'created_at': '2026-10-29T10:30:00+08:00',
      'items': [
        {'name': 'Chicken Rice', 'quantity': 1},
      ],
    });

    expect(ticket.displayOrderer, 'Ahmad');
    expect(ticket.displayRemarks, 'No chilli');
  });

  test('groups department tickets by their order number within one sale', () {
    final first = KitchenTicket(
      messageId: 'message-1',
      saleId: 'sale-1',
      departmentId: 'kitchen',
      revision: 1,
      action: 'upsert',
      orderNumber: '104',
      createdAt: DateTime(2026),
      items: [],
    );
    final second = KitchenTicket(
      messageId: 'message-2',
      saleId: 'sale-1',
      departmentId: 'beverages',
      revision: 1,
      action: 'upsert',
      orderNumber: '104',
      createdAt: DateTime(2026),
      items: [],
    );
    final otherSale = KitchenTicket(
      messageId: 'message-3',
      saleId: 'sale-2',
      departmentId: 'kitchen',
      revision: 1,
      action: 'upsert',
      orderNumber: '104',
      createdAt: DateTime(2026),
      items: [],
    );

    final groups = groupKitchenTicketsByOrder([first, second, otherSale]);

    expect(groups, hasLength(2));
    expect(groups.first, [first, second]);
  });

  test('formats whole item quantities without a decimal', () {
    expect(
      const KitchenTicketItem(name: 'Nasi goreng', quantity: 1.0).displayQuantity,
      '1',
    );
    expect(
      const KitchenTicketItem(name: 'Fish', quantity: 0.5).displayQuantity,
      '0.5',
    );
  });
}
