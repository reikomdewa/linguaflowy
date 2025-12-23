import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:linguaflow/theme/colors.dart';
import 'package:linguaflow/constants/styles.dart';
import 'package:linguaflow/constants/values.dart';

String howToPay = '''
<p> Note that only Mobile Money Payment is available at the moment</p>
<p> Also the transactions you make are confirmed by a human to avoid fraudulant.
 Your purchase should be enabled in less than 24 hours</p>
<p> The steps to pay: </p>
<ul>
<li> Choose the subscription you want to purchase</li>
<li> Deposit the money in our account number : <b>$mwamba</b>.</li>
<li> Open Rama, go to the premium page and choose the subscription according to your deposit</li>
<li> Enter your name you use in mobile money and
email you used to sign in into Rama </li>
<li> And the message from Mobile Money provider. e.g MTN or Airtel
<li>Or alternatively, you can SMS or Whatsapp Reikom Academy by clicking the Whatsapp button on premium tab those same details i.e
<ol>
<li>Name you use in mobile money</li>
<li>Email you used to sign in </li>
<li>Message from Mobile Money provider</li>
</ol>

</ul>
<p>We use information such as Transaction ID, amount deposited and Date to activate your premium. It should be activated in less than an hour. Give us 24 hours to activate your purchase.
 If it is not activated for more than an hour: email us at reikomacademy@gmail.com.
''';

class HowToPayPage extends StatefulWidget {
  const HowToPayPage({Key? key}) : super(key: key);

  @override
  State<HowToPayPage> createState() => _HowToPayPageState();
}

class _HowToPayPageState extends State<HowToPayPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: secondary,
        appBar:
            AppBar(backgroundColor: secondary, title: const Text('How to Pay')),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                Html(data: howToPay, style: {
                  "p": Style(
                    fontWeight: FontWeight.w700,
                    fontSize: FontSize(16.0),
                    color: Colors.white,
                  ),
                  "li": listInstructionTextStyle
                }),
              ],
            ),
          ),
        )));
  }
}
