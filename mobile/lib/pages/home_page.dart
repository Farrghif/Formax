import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
    );
  }

  Column searchBar() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: 5, left: 5, right: 5),
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
              contentPadding: EdgeInsets.all(10),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset('assets/icons/searchicon.svg'),
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(55),
                borderSide: BorderSide.none
              ),
            ),
          ),
        )
      ],
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
      centerTitle: false,
      leading: GestureDetector(
        onTap: () {},
        child: Container(
        margin: EdgeInsets.all(5),
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1, left: 10, right: 5),
          child: SvgPicture.asset('assets/icons/pP.svg'),
        ),
      ),
      
        // decoration: BoxDecoration(
        //   color: const Color.fromARGB(255, 204, 26, 26),
        //   borderRadius: BorderRadius.circular(10),
        // ),
      ),
      actions: [
        Container(
        margin: EdgeInsets.all(10),
        alignment: Alignment.center,
        width: 37,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1, left: 5, right: 10),
          child: const Icon(Icons.menu, color: Colors.white, ),
        ),
      ),
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 25, left: 5, right: 5),
          child: searchBar(),
          )
        ),
    );
  }
}
