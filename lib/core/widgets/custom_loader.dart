import 'package:flutter/material.dart';

class CustomLoader extends StatelessWidget {
  const CustomLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Center(
      child: SizedBox(
        width: 180,
        child: LinearProgressIndicator(
          minHeight: 4,
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(context).colorScheme.secondary,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
