import 'package:flutter/material.dart';
import 'package:linguaflow/theme/colors.dart';
import 'package:flutter_html/flutter_html.dart';

class AppStyles {
  // ===========================================================================
  // HTML STYLES (flutter_html)
  // ===========================================================================
  
  static Style lessonTextStyle(BuildContext context) => Style(
    fontSize: FontSize(16.0),
    // Maps to dynamic dark/light text color
    color: AppColor.homePageContainerTextSmall(context), 
  );

  static Style listTextStyle(BuildContext context) => Style(
    lineHeight: LineHeight.number(1.2),
    fontSize: FontSize(16.0),
    color: AppColor.homePageContainerTextSmall(context),
  );

  static Style listInstructionTextStyle(BuildContext context) => Style(
    lineHeight: LineHeight.number(1.2),
    fontSize: FontSize(16.0),
    // Instructions usually need to stand out or be white on dark backgrounds
    color: AppColor.homePageTitle(context), 
  );

  // ===========================================================================
  // TEXT STYLES
  // ===========================================================================

  static TextStyle kSendButtonTextStyle(BuildContext context) => TextStyle(
    color: AppColor.gradientFirst, // Use the primary HyperBlue
    fontWeight: FontWeight.bold,
    fontSize: 18.0,
  );

  static TextStyle textMsgStyle(BuildContext context) => TextStyle(
    fontSize: 16, 
    color: AppColor.homePageTitle(context) // Adapts to Black/White
  );

  static TextStyle textFadeStyle(BuildContext context) => TextStyle(
    fontSize: 12, 
    color: AppColor.homePageSubtitle(context) // Adapts to Grey
  );

  static TextStyle decoTextStyle(BuildContext context) => TextStyle(
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );

  static TextStyle textNameStyle(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle kTitleStyle(BuildContext context) => TextStyle(
    color: AppColor.homePageTitle(context),
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static TextStyle smallSubtitleStyle(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageContainerTextSmall(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle subtitleStyle(BuildContext context) => TextStyle(
    fontSize: 18,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle subtitleStyleBlack(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageSubtitle(context), // Use dynamic grey
    fontWeight: FontWeight.w700,
  );

  static TextStyle titleStyleBlack(BuildContext context) => TextStyle(
    fontSize: 18,
    color: AppColor.homePageSubtitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle smallText(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageContainerTextSmall(context),
    fontWeight: FontWeight.w500,
  );

  static TextStyle smallTextBlack(BuildContext context) => TextStyle(
    fontSize: 15,
    color: AppColor.homePageSubtitle(context),
    fontWeight: FontWeight.w400,
  );

  static TextStyle titleStyleBig(BuildContext context) => TextStyle(
    fontSize: 28,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle titleStyleBigPro(BuildContext context) => TextStyle(
    fontSize: 28,
    // Keep the "Pro" color (Amber) consistent across themes
    color: AppColor.homePageContainerTextSmallPro, 
    fontWeight: FontWeight.w700,
  );

  static TextStyle promoTextStyle(BuildContext context) => const TextStyle(
    fontSize: 15.0,
    color: Colors.white, // Promo text usually on colored bg, keep white
    fontWeight: FontWeight.w500,
  );

  static TextStyle youtubeVideoTitleStyle(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageContainerTextSmall(context),
    fontWeight: FontWeight.w500,
  );

  static TextStyle videoTitle(BuildContext context) => TextStyle(
    color: AppColor.secondary, // Maps to Charcoal (Dark) or standard Secondary
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
  );

  static TextStyle videoTitleStyle(BuildContext context) => TextStyle(
    fontSize: 20,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle videoTitleStyleSmall(BuildContext context) => TextStyle(
    fontSize: 18,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );

  static TextStyle courseTitleStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: AppColor.homePageTitle(context).withOpacity(0.8),
  );

  static TextStyle courseDescriptionStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 17,
    color: AppColor.homePageSubtitle(context),
  );

  static TextStyle courseTimeStyle(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageSubtitle(context),
  );

  static TextStyle courseTimeSmallStyle(BuildContext context) => TextStyle(
    fontSize: 16,
    color: AppColor.homePageSubtitle(context),
  );

  static TextStyle nextButtonStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 17,
    color: AppColor.homePageTitle(context),
  );

  static TextStyle lessonContentTitleStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 25,
    color: AppColor.homePageTitle(context),
  );

  static TextStyle scoreTitleStyleBig(BuildContext context) => TextStyle(
    fontSize: 28,
    color: AppColor.homePageTitle(context),
    fontWeight: FontWeight.w700,
  );
}