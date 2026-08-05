import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 35, left: 20, right: 20),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0XFFB4C5D4).withOpacity(0.11),
                  blurRadius: 40,
                  spreadRadius: 0.0
                )
              ]
            ),
            child: TextField(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.all(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      foregroundColor: Colors.blue,
      title: Text(
        'Form4x',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Color(0xFFB4C5D4),
      centerTitle: true,
      leading: GestureDetector(
        onTap: () {},
        child: Container(
        margin: EdgeInsets.all(10),
        alignment: Alignment.center,
        child: const Icon(Icons.menu, color: Colors.white, ),
      ),
      
        // decoration: BoxDecoration(
        //   color: const Color.fromARGB(255, 204, 26, 26),
        //   borderRadius: BorderRadius.circular(10),
        // ),
      ),
    );
  }
}
