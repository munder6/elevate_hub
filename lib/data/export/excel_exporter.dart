import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

import '../../data/models/session.dart';
import '../../data/models/order.dart';
import '../../data/models/expense.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/debt.dart';

class ExcelExporter {
  Future<File> buildAndSave({
    required DateTime from,
    required DateTime to,
    required List<Session> sessions,
    required List<OrderModel> orders,
    required List<Expense> expensesVariable,
    required Map<String, List<Expense>> expensesFixedByMonth, // mk -> list
    required List<InventoryItem> inventory,
    required List<Debt> debts,
    required num revenue,
    required num expenses,
    required num net,
    String? topDrink,
  }) async {
    final wb = xls.Workbook();

    // Summary
        {
      final s = wb.worksheets[0];
      s.name = 'Summary';
      s.getRangeByName('A1').setText('From');
      s.getRangeByName('B1').setText(from.toIso8601String());
      s.getRangeByName('A2').setText('To');
      s.getRangeByName('B2').setText(to.toIso8601String());
      s.getRangeByName('A4').setText('Revenue');
      s.getRangeByName('B4').setNumber(revenue.toDouble());
      s.getRangeByName('A5').setText('Expenses');
      s.getRangeByName('B5').setNumber(expenses.toDouble());
      s.getRangeByName('A6').setText('Net');
      s.getRangeByName('B6').setNumber(net.toDouble());
      s.getRangeByName('A8').setText('Top Drink');
      s.getRangeByName('B8').setText(topDrink ?? '-');
      // (اختياري) ضبط أعمدة summary:
      s.getRangeByIndex(1, 1, 8, 2).autoFitColumns();
    }

    // Sessions
        {
      final s = wb.worksheets.addWithName('Sessions');
      s.getRangeByName('A1').setText('Date');
      s.getRangeByName('B1').setText('Member');
      s.getRangeByName('C1').setText('Minutes');
      s.getRangeByName('D1').setText('Rate');
      s.getRangeByName('E1').setText('Drinks');
      s.getRangeByName('F1').setText('Discount');
      s.getRangeByName('G1').setText('GrandTotal');
      s.getRangeByName('H1').setText('Status');

      var r = 2;
      for (final e in sessions) {
        s.getRangeByIndex(r, 1).setText(e.checkInAt?.toString().substring(0, 16) ?? '');
        s.getRangeByIndex(r, 2).setText(e.memberName ?? e.memberId ?? '');
        s.getRangeByIndex(r, 3).setNumber((e.minutes ?? 0).toDouble());
        s.getRangeByIndex(r, 4).setNumber((e.hourlyRateAtTime ?? 0).toDouble());
        s.getRangeByIndex(r, 5).setNumber((e.drinksTotal ?? 0).toDouble());
        s.getRangeByIndex(r, 6).setNumber((e.discount ?? 0).toDouble());
        s.getRangeByIndex(r, 7).setNumber((e.grandTotal ?? 0).toDouble());
        s.getRangeByIndex(r, 8).setText(e.status ?? '');
        r++;
      }
      final lastRow = (r - 1).clamp(1, 1000000);
      s.getRangeByIndex(1, 1, lastRow, 8).autoFitColumns();
    }

    // Orders
        {
      final s = wb.worksheets.addWithName('Orders');
      s.getRangeByName('A1').setText('Date');
      s.getRangeByName('B1').setText('Item');
      s.getRangeByName('C1').setText('Qty');
      s.getRangeByName('D1').setText('UnitPrice');
      s.getRangeByName('E1').setText('Total');
      s.getRangeByName('F1').setText('Linked');
      s.getRangeByName('G1').setText('Member');

      var r = 2;
      for (final o in orders) {
        s.getRangeByIndex(r, 1).setText(o.createdAt?.toString().substring(0, 16) ?? '');
        s.getRangeByIndex(r, 2).setText(o.itemName ?? '');
        s.getRangeByIndex(r, 3).setNumber((o.qty ?? 0).toDouble());
        s.getRangeByIndex(r, 4).setNumber((o.unitPriceAtTime ?? 0).toDouble());
        s.getRangeByIndex(r, 5).setNumber((o.total ?? 0).toDouble());
        s.getRangeByIndex(r, 6).setText(
          o.sessionId != null
              ? 'session:${o.sessionId}'
              : o.weeklyCycleId != null
              ? 'weekly:${o.weeklyCycleId}'
              : o.monthlyCycleId != null
              ? 'monthly:${o.monthlyCycleId}'
              : '-',
        );
        s.getRangeByIndex(r, 7).setText(o.memberName ?? o.memberId ?? '-');
        r++;
      }
      final lastRow = (r - 1).clamp(1, 1000000);
      s.getRangeByIndex(1, 1, lastRow, 6).autoFitColumns();
    }

    // Expenses variable
        {
      final s = wb.worksheets.addWithName('ExpensesVar');
      s.getRangeByName('A1').setText('Date');
      s.getRangeByName('B1').setText('Category');
      s.getRangeByName('C1').setText('Amount');
      s.getRangeByName('D1').setText('Reason');

      var r = 2;
      for (final e in expensesVariable) {
        s.getRangeByIndex(r, 1).setText(e.createdAt?.toString().substring(0, 16) ?? '');
        s.getRangeByIndex(r, 2).setText(e.category);
        s.getRangeByIndex(r, 3).setNumber((e.amount).toDouble());
        s.getRangeByIndex(r, 4).setText(e.reason ?? '');
        r++;
      }
      final lastRow = (r - 1).clamp(1, 1000000);
      s.getRangeByIndex(1, 1, lastRow, 4).autoFitColumns();
    }

    // Expenses fixed monthly (Sheet لكل شهر)
        {
      for (final entry in expensesFixedByMonth.entries) {
        final s = wb.worksheets.addWithName('Fixed_${entry.key}');
        s.getRangeByName('A1').setText('Category');
        s.getRangeByName('B1').setText('Amount');
        s.getRangeByName('C1').setText('Reason');

        var r = 2;
        for (final e in entry.value) {
          s.getRangeByIndex(r, 1).setText(e.category);
          s.getRangeByIndex(r, 2).setNumber(e.amount.toDouble());
          s.getRangeByIndex(r, 3).setText(e.reason ?? '');
          r++;
        }
        final lastRow = (r - 1).clamp(1, 1000000);
        s.getRangeByIndex(1, 1, lastRow, 3).autoFitColumns();
      }
    }

    // Inventory snapshot
        {
      final s = wb.worksheets.addWithName('Inventory');
      s.getRangeByName('A1').setText('Name');
      s.getRangeByName('B1').setText('SKU');
      s.getRangeByName('C1').setText('Category');
      s.getRangeByName('D1').setText('Unit');
      s.getRangeByName('E1').setText('Stock');
      s.getRangeByName('F1').setText('Min');

      var r = 2;
      for (final i in inventory) {
        s.getRangeByIndex(r, 1).setText(i.name);
        s.getRangeByIndex(r, 2).setText(i.sku ?? '');
        s.getRangeByIndex(r, 3).setText(i.category ?? '');
        s.getRangeByIndex(r, 4).setText(i.unit);
        s.getRangeByIndex(r, 5).setNumber(i.stock.toDouble());
        s.getRangeByIndex(r, 6).setNumber(i.minStock.toDouble());
        r++;
      }
      final lastRow = (r - 1).clamp(1, 1000000);
      s.getRangeByIndex(1, 1, lastRow, 6).autoFitColumns();
    }

    // Debts
        {
      final s = wb.worksheets.addWithName('Debts');
      s.getRangeByName('A1').setText('Member');
      s.getRangeByName('B1').setText('Amount');
      s.getRangeByName('C1').setText('Status');
      s.getRangeByName('D1').setText('CreatedAt');

      var r = 2;
      for (final d in debts) {
        s.getRangeByIndex(r, 2).setText(d.memberName ?? d.memberId ?? '');
        s.getRangeByIndex(r, 2).setNumber((d.amount ?? 0).toDouble());
        s.getRangeByIndex(r, 3).setText(d.status ?? '');
        s.getRangeByIndex(r, 4).setText(d.createdAt?.toString().substring(0, 16) ?? '');
        r++;
      }
      final lastRow = (r - 1).clamp(1, 1000000);
      s.getRangeByIndex(1, 1, lastRow, 4).autoFitColumns();
    }

    final bytes = wb.saveAsStream();
    wb.dispose();

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/report_${from.toIso8601String().substring(0,10)}_${to.toIso8601String().substring(0,10)}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
