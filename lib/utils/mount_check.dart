import 'package:flutter/material.dart';

bool mountCheck(BuildContext context) {
  try {
    return context.mounted;
  } catch (e) {
    return false;
  }
}
