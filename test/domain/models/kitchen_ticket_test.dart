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
      'created_at': '2026-10-29T10:30:00+08:00',
      'items': [
        {'name': 'Chicken Rice', 'quantity': 2, 'comments': 'No chilli'},
      ],
    });

    expect(ticket.id, 'sale-1:department-1');
    expect(ticket.revision, 2);
    expect(ticket.items.single.name, 'Chicken Rice');
  });
}
