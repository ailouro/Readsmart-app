import 'package:flutter/material.dart';

class SkewedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  
  const SkewedButton({Key? key, required this.text, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Transform(
        transform: Matrix4.skewX(-0.3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Transform(
            transform: Matrix4.skewX(0.3),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
