import 'package:flutter/material.dart';



var bannerItems=[
  'Türkçe',
  'Matematik',
  'Tarih',
  'Coğrafya',
  'Felsefe',
  'Din',
  'Fizik',
  'Kimya',
  'Biyoloji',
];
var bannerImage = [
  "images/turkce.jpg",
  "images/matematik.jpg",
  "images/tarih.jpg",
  "images/cografya.jpg",
  "images/felsefe.jpg",
  "images/din.jpg",
  "images/fizik.jpg",
  "images/kimya.jpg",
  "images/biyoloji.jpg",
];


class BannerWidgetArea extends StatelessWidget {
  const BannerWidgetArea({super.key});

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    var screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    PageController controller = PageController(initialPage: 1);
    List<Widget> banners = [];


    for (int x = 0; x < bannerItems.length; x++) {
      var bannerWiew =Padding(padding: EdgeInsets.all(10),
        child: Container(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius:BorderRadius.all(Radius.circular(20.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(4.0, 4.0),
                      blurRadius: 5.0,
                      spreadRadius: 1.0,
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius:BorderRadius.all(Radius.circular(20.0),),
                child: Image.asset(bannerImage[x], fit: BoxFit.cover),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bannerItems[x],style: TextStyle(fontSize: 30,color: Colors.white),),
                  Text(""),
                ],
              ),
            ],
          ),
        ),
      );
      banners.add(bannerWiew);
    }
    return Container(
      width: screenWidth,
      height: screenHeight *0.35,
      child: PageView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        children: banners,
      ),
    );
  }
}