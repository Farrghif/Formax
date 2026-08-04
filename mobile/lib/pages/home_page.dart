import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.blue,
        title: Text(
          'Form4x',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
        leading: Container(
          margin: EdgeInsets.all(10),
          child: const Icon(Icons.menu, color: Colors.white),
          // decoration: BoxDecoration(
          //   color: const Color.fromARGB(255, 204, 26, 26),
          //   borderRadius: BorderRadius.circular(10),
          // ),
        ),
      ),
    );
  }
}
