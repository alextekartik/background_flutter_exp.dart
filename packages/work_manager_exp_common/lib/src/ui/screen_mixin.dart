import 'package:flutter/material.dart';

mixin ExpScreenMixin<T extends StatefulWidget> implements State<T> {
  void snackInfo(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
