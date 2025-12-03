import 'package:flutter/material.dart';

class NumpadWidget extends StatelessWidget {
  final ValueChanged<String> onNumberPressed;
  final VoidCallback onDeletePressed;

  const NumpadWidget({
    Key? key,
    required this.onNumberPressed,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        ...List.generate(
            9, (index) => _buildNumpadButton((index + 1).toString())),
        Container(), // Empty space for layout
        _buildNumpadButton('0'),
        _buildNumpadButton('⌫', onPressed: onDeletePressed),
      ],
    );
  }

  Widget _buildNumpadButton(String text, {VoidCallback? onPressed}) {
    return TextButton(
      onPressed: onPressed ?? () => onNumberPressed(text),
      child: text == '⌫'
          ? const Icon(Icons.backspace_outlined, size: 28)
          : Text(text, style: const TextStyle(fontSize: 28)),
    );
  }
}
