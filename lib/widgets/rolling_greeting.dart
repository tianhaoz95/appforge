import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RollingGreeting extends StatefulWidget {
  final TextStyle? style;
  final Duration animationDuration;
  final Duration switchDuration;

  const RollingGreeting({
    super.key,
    this.style,
    this.animationDuration = const Duration(milliseconds: 500),
    this.switchDuration = const Duration(seconds: 1),
  });

  @override
  State<RollingGreeting> createState() => _RollingGreetingState();
}

class _RollingGreetingState extends State<RollingGreeting> {
  final List<String> _options = [
    'an app!',
    'a TODO app!',
    'a workout plan!',
    'a budgeting app!',
    'a recipe book!',
    'a habit tracker!',
    'a daily journal!',
    'a fitness tracker!',
    'a travel planner!',
    'a shopping list!',
  ];

  int _currentIndex = 0;
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.switchDuration, (timer) {
      if (mounted) {
        setState(() {
          int nextIndex;
          do {
            nextIndex = _random.nextInt(_options.length);
          } while (nextIndex == _currentIndex);
          _currentIndex = nextIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style?.fontSize ?? 24.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "let's build ",
          style: widget.style,
        ),
        AnimatedSize(
          duration: widget.animationDuration,
          child: SizedBox(
            height: fontSize * 1.5,
            child: AnimatedSwitcher(
              duration: widget.animationDuration,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final isIncoming = child.key == ValueKey<String>(_options[_currentIndex]);
                
                final slideAnimation = isIncoming
                    ? Tween<Offset>(
                        begin: const Offset(0.0, 1.0),
                        end: const Offset(0.0, 0.0),
                      ).animate(animation)
                    : Tween<Offset>(
                        begin: const Offset(0.0, -1.0),
                        end: const Offset(0.0, 0.0),
                      ).animate(animation);

                return ClipRect(
                  child: SlideTransition(
                    position: slideAnimation,
                    child: child,
                  ),
                );
              },
              child: Text(
                _options[_currentIndex],
                key: ValueKey<String>(_options[_currentIndex]),
                style: widget.style,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
