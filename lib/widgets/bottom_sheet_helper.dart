import 'package:flutter/material.dart';

const double appBottomNavClearance = 96;
const double appBottomSheetKeyboardGap = 14;

EdgeInsets appBottomSheetInsets(
  BuildContext context, {
  double left = 16,
  double right = 16,
  double top = 24,
  double bottomNavClearance = appBottomNavClearance,
  double keyboardGap = appBottomSheetKeyboardGap,
}) {
  final mediaQuery = MediaQuery.of(context);
  final keyboardInset = mediaQuery.viewInsets.bottom;
  final safeBottom = mediaQuery.padding.bottom;
  final bottom = keyboardInset > 0
      ? keyboardInset + keyboardGap
      : safeBottom + bottomNavClearance;
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

Widget buildAppBottomSheetFrame(
  BuildContext context, {
  required Widget child,
  Alignment alignment = Alignment.bottomCenter,
  double left = 16,
  double right = 16,
  double top = 24,
  double maxWidth = 520,
  double maxHeightFactor = 0.86,
  double bottomNavClearance = appBottomNavClearance,
  double keyboardGap = appBottomSheetKeyboardGap,
}) {
  final size = MediaQuery.of(context).size;
  return Padding(
    padding: appBottomSheetInsets(
      context,
      left: left,
      right: right,
      top: top,
      bottomNavClearance: bottomNavClearance,
      keyboardGap: keyboardGap,
    ),
    child: Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height * maxHeightFactor,
        ),
        child: child,
      ),
    ),
  );
}
