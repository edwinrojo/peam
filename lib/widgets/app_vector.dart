import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppVector extends StatelessWidget {
  const AppVector(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      placeholderBuilder: (context) => SizedBox(
        width: width,
        height: height,
      ),
    );
  }
}
