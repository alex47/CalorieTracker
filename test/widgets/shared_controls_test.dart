import 'package:calorie_tracker/theme/app_colors.dart';
import 'package:calorie_tracker/widgets/app_button.dart';
import 'package:calorie_tracker/widgets/app_dialog.dart';
import 'package:calorie_tracker/widgets/dialog_action_row.dart';
import 'package:calorie_tracker/widgets/food_table_card.dart';
import 'package:calorie_tracker/widgets/labeled_dropdown_box.dart';
import 'package:calorie_tracker/widgets/labeled_group_box.dart';
import 'package:calorie_tracker/widgets/labeled_input_box.dart';
import 'package:calorie_tracker/widgets/labeled_progress_bar.dart';
import 'package:calorie_tracker/widgets/selected_surface.dart';
import 'package:calorie_tracker/widgets/wizard_step_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('shared buttons', () {
    testWidgets('supports enabled, disabled, loading, and icon interactions',
        (tester) async {
      var enabledTaps = 0;
      var iconTaps = 0;
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton(
                  onPressed: () => enabledTaps += 1,
                  icon: const Icon(Icons.save_outlined),
                  label: 'Enabled',
                ),
                const AppButton(
                  onPressed: null,
                  icon: Icon(Icons.block_outlined),
                  label: 'Disabled',
                ),
                const AppButton(
                  onPressed: null,
                  icon: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: 'Loading',
                ),
                AppIconButton(
                  onPressed: () => iconTaps += 1,
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enabled'));
      await tester.tap(find.text('Disabled'));
      await tester.tap(find.byTooltip('Refresh'));
      expect(enabledTaps, 1);
      expect(iconTaps, 1);
      expect(_button('Disabled').onPressed, isNull);
      expect(_button('Loading').onPressed, isNull);
      expect(
        find.descendant(
          of: _buttonFinder('Loading'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });

  group('shared fields', () {
    testWidgets('propagates enabled input and blocks disabled input',
        (tester) async {
      final enabledController = TextEditingController();
      final disabledController = TextEditingController(text: 'fixed');
      addTearDown(enabledController.dispose);
      addTearDown(disabledController.dispose);
      String? changedValue;
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: Column(
              children: [
                LabeledInputBox(
                  label: 'Enabled input',
                  controller: enabledController,
                  onChanged: (value) => changedValue = value,
                ),
                LabeledInputBox(
                  label: 'Disabled input',
                  controller: disabledController,
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(_input('Enabled input'), '123');
      expect(enabledController.text, '123');
      expect(changedValue, '123');
      expect(
        tester.widget<TextField>(_input('Disabled input')).enabled,
        isFalse,
      );
      expect(disabledController.text, 'fixed');
    });

    testWidgets('dropdown opens, changes value, and respects disabled state',
        (tester) async {
      var selected = 'a';
      var enabled = true;
      late StateSetter setHostState;
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return LabeledDropdownBox<String>(
                  label: 'Choice',
                  value: selected,
                  enabled: enabled,
                  items: const [
                    DropdownMenuItem(value: 'a', child: Text('Alpha')),
                    DropdownMenuItem(value: 'b', child: Text('Beta')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selected = value);
                    }
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();
      expect(selected, 'b');
      expect(find.text('Beta'), findsOneWidget);

      setHostState(() => enabled = false);
      await tester.pump();
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      expect(selected, 'b');
    });
  });

  testWidgets('food table preserves tap, long-press, and selection styling',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: FoodTableCard(
            columns: const [
              FoodTableColumn(label: 'Food'),
              FoodTableColumn(label: 'Amount'),
              FoodTableColumn(label: 'Calories'),
            ],
            rows: [
              FoodTableRowData(
                onTap: () => taps += 1,
                onLongPress: () => longPresses += 1,
                backgroundColor: AppColors.selectionHighlight,
                borderColor: AppColors.selectionBorder,
                cells: const [
                  FoodTableCell(text: 'Apple'),
                  FoodTableCell(text: '100 g'),
                  FoodTableCell(text: '52'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widgetList<SelectedSurface>(find.byType(SelectedSurface)).any(
            (surface) => surface.selected,
          ),
      isTrue,
    );
    await tester.tap(find.text('Apple'));
    await tester.longPress(find.text('Apple'));
    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('group, progress, wizard, and dialog fit a narrow layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                LabeledGroupBox(
                  label: 'Long group label',
                  value: 'Value',
                  borderColor: AppColors.subtleBorder,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const LabeledProgressBar(
                  label: 'Progress',
                  value: 1234,
                  goal: 100,
                  color: AppColors.calories,
                  inlineStatusText:
                      'A deliberately long status that must not overflow',
                ),
                const SizedBox(height: 12),
                const WizardStepBar(currentStep: 1, totalSteps: 3),
                const SizedBox(height: 12),
                AppButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AppDialog(
                      title: const Text('Narrow dialog'),
                      content: const Text('Dialog content'),
                      actionItems: [
                        DialogActionItem(
                          child: AppButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.save_outlined),
                            label: 'Save a long value',
                          ),
                        ),
                        const DialogActionItem(
                          child: AppButton(
                            onPressed: null,
                            icon: Icon(Icons.block_outlined),
                            label: 'Disabled action',
                          ),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: 'Open dialog',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Narrow dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _input(String label) {
  return find.descendant(
    of: find.widgetWithText(LabeledInputBox, label),
    matching: find.byType(TextField),
  );
}

Finder _buttonFinder(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;
}

ButtonStyleButton _button(String label) {
  return _buttonFinder(label).evaluate().single.widget as ButtonStyleButton;
}
