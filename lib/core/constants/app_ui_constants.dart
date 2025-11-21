import 'package:flutter/material.dart';

class AppSpacing {
  static const Widget verticalTiny = SizedBox(height: 4);
  static const Widget verticalSmall = SizedBox(height: 8);
  static const Widget verticalMedium = SizedBox(height: 16);
  static const Widget verticalLarge = SizedBox(height: 24);
  static const Widget verticalXLarge = SizedBox(height: 32);
  
  static const Widget horizontalTiny = SizedBox(width: 4);
  static const Widget horizontalSmall = SizedBox(width: 8);
  static const Widget horizontalMedium = SizedBox(width: 16);
  static const Widget horizontalLarge = SizedBox(width: 24);
  static const Widget horizontalXLarge = SizedBox(width: 32);
}

class AppBorderRadius {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(16));
  static const BorderRadius xLarge = BorderRadius.all(Radius.circular(20));
  
  static const BorderRadius onlyTopLarge = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
  );
  
  static const BorderRadius onlyBottomLarge = BorderRadius.only(
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );
}

class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}