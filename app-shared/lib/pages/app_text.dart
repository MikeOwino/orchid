import 'package:flutter/material.dart';
import 'package:orchid/pages/app_colors.dart';

class AppText {
  static TextStyle headerStyle = TextStyle(
    letterSpacing: 0.0,
    //height: 1.32,
    color: AppColors.text_header_purple,
    fontWeight: FontWeight.w500,
    fontFamily: "Roboto",
    fontStyle: FontStyle.normal,
    fontSize: 24.0,
  );

  static Text header(
      {text: String,
      textAlign: TextAlign.center,
      color: AppColors.text_header_purple,
      fontWeight: FontWeight.w500,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 24.0}) {
    return Text(text,
        textAlign: textAlign,
        style: TextStyle(
            color: color,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            fontStyle: fontStyle,
            fontSize: fontSize));
  }

  static TextStyle bodyStyle = TextStyle(
      color: AppColors.neutral_2,
      letterSpacing: 0.0,
      height: 1.32,
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 14.0);

  static Text body(
      {text: "",
      textAlign: TextAlign.center,
      color: AppColors.neutral_2,
      letterSpacing: 0.0,
      lineHeight: 1.32,
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 14.0}) {
    return Text(text,
        textAlign: textAlign,
        style: TextStyle(
            color: color,
            letterSpacing: letterSpacing,
            height: lineHeight,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            fontStyle: fontStyle,
            fontSize: fontSize));
  }

  static TextStyle hintStyle = TextStyle(
      color: AppColors.neutral_1,
      letterSpacing: 0.15,
      //height: 1.5,
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 16.0);

  static TextStyle buttonStyle = TextStyle(
      color: AppColors.grey_7,
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 14.0);

  static TextStyle dialogTitle = const TextStyle(
      color: const Color(0xff3a3149),
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 20.0);

  static TextStyle dialogBody = const TextStyle(
      color: const Color(0xff504960),
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 16.0);

  static TextStyle dialogButton = const TextStyle(
      letterSpacing: 1.25,
      color: const Color(0xff5f45ba),
      fontWeight: FontWeight.w400,
      fontFamily: "Roboto",
      fontStyle: FontStyle.normal,
      fontSize: 14.0);

}
