import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class ClicksPerYear {
  final String year;
  final int clicks;
  final charts.Color color;

  ClicksPerYear(this.year, this.clicks, Color color)
      : this.color = new charts.Color(
            r: color.red, g: color.green, b: color.blue, a: color.alpha);
}


class ClicksOverTime {
  final DateTime time;
  final int value;

  ClicksOverTime(this.time, this.value);
}


