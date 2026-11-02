import 'package:flutter/widgets.dart';

class SlantedTimerClipper extends CustomClipper<Path> {
  const SlantedTimerClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .36, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width * .26, size.height)
    ..close();

  @override
  bool shouldReclip(covariant SlantedTimerClipper oldClipper) => false;
}
