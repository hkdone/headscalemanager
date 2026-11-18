import 'package:material_ui/material_ui.dart';

bool mountCheck(BuildContext context) {
  try {
    return context.mounted;
  } catch (e) {
    return false;
  }
}
