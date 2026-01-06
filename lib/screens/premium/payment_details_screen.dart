// import 'package:flutter/material.dart';
// import 'package:linguaflow/theme/colors.dart';
// import 'package:linguaflow/constants/styles.dart';

// import 'package:url_launcher/url_launcher.dart';

// class PaymentDetailsPage extends StatefulWidget {
//   const PaymentDetailsPage({Key? key}) : super(key: key);

//   @override
//   State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
// }

// class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
//   final controllerTo = TextEditingController();
//   final nameController = TextEditingController();
//   final emailController = TextEditingController();
//   final controllerMessage = TextEditingController();
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: secondary,

//       // drawer: Drawer(
//       //   child: Stack(children: const [DrawerScreen(), SecondDrawerScreen()]),
//       // ),
//       appBar: AppBar(
//         backgroundColor: secondary,
//         //toolbarHeight: 30,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: SingleChildScrollView(
//             physics: const BouncingScrollPhysics(),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 7),
//                 Text(
//                   'Make sure you have already deposited in mobile money before you send the email.',
//                   style: subtitleStyle,
//                 ),
//                 const SizedBox(height: 15),
//                 Text(
//                   'We use information such transaction ID, date, and amount to comfirm the transaction and activate your premium',
//                   style: smallText,
//                 ),
//                 const SizedBox(height: 8),
//                 buildTextField(
//                   hintTextString: 'Enter your name',
//                   title: 'Your full name you use in mobile money',
//                   controller: nameController,
//                   maxLines: 1,
//                 ),
//                 const SizedBox(height: 12),
//                 buildTextField(
//                   hintTextString: 'Enter your email',
//                   title: 'Your email of this account',
//                   controller: emailController,
//                   maxLines: 1,
//                 ),
//                 buildTextField(
//                   hintTextString: 'Paste the message here',
//                   title:
//                       'Copy and paste the Message from mobile money money provider e.g MTN. ',
//                   controller: controllerMessage,
//                   maxLines: 8,
//                 ),

//                 const SizedBox(height: 12),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: const Size.fromHeight(50),
//                     textStyle: const TextStyle(fontSize: 20),
//                   ),
//                   onPressed: () {
//                     launchEmail(
//                       toEmail: 'reikomacademy@gmail.com',
//                       subject:
//                           'Name: ${nameController.text}\nemail: ${emailController.text}',
//                       message: controllerMessage.text,
//                     );
//                     //showSnackBar(context, text)
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         duration: Duration(seconds: 2, milliseconds: 1500),
//                         behavior: SnackBarBehavior.floating,
//                         margin: EdgeInsets.only(bottom: 200),
//                         content: Text(
//                           'Thanks, Your purchase will be activated',
//                           style: TextStyle(fontSize: 18),
//                         ),
//                       ),
//                     );
//                   },
//                   child: const Text('SEND'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget buildSendButton({
//     required String text,
//     required VoidCallback onClicked,
//   }) {
//     return ElevatedButton(onPressed: onClicked, child: Text(text));
//   }

//   Widget buildTextField({
//     required String title,
//     required TextEditingController controller,
//     required int maxLines,
//     required String hintTextString,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: subtitleStyle),
//         const SizedBox(height: 8),
//         TextField(
//           style: const TextStyle(fontSize: 16),
//           maxLines: maxLines,
//           controller: controller,
//           decoration: InputDecoration(
//             fillColor: Colors.grey[300],
//             filled: true,
//             hintText: hintTextString,
//             border: const OutlineInputBorder(),
//           ),
//         ),
//       ],
//     );
//   }

//   Future launchEmail({
//     required String toEmail,
//     required String subject,
//     required String message,
//   }) async {
//     final url =
//         'mailto:$toEmail?subject=${Uri.encodeFull(subject)}&body=${Uri.encodeFull(message)}';
//     await launchUrl(Uri.parse(url));
//   }
// }
