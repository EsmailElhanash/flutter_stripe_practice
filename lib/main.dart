import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stripe_payment/stripe_payment.dart';

import 'Dialog.dart';

//
//
String text = 'Click the button to start the payment';
double totalCost = 10.0;
double tip = 1.0;
double tax = 5.0;
double taxPercent = 0.2;
int amount = 100;
bool showSpinner = false;
String url =
    'http://10.0.2.2:5001/flutter-stripe-practice/us-central1/StripePI';
//http://localhost:5001/flutter-stripe-practice/us-central1/StripePI
String txt = "Pay";

String publishableKey =
    "pk_test_51JQbtnDFt4tW72zryvXPrPUUi6y8ffzc9KwkwTgwxTQccKCe1UOYhvqdK3JsRcCdRGiJHYgzpey9AeyFfGwKRZxA00F9wHDiYR";
//
//

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PaymentPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class PaymentPage extends StatefulWidget {
  PaymentPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyPaymentState createState() => _MyPaymentState();
}

class _MyPaymentState extends State<PaymentPage> {
  void initState() {
    super.initState();
    StripePayment.setOptions(
      StripeOptions(
        publishableKey: publishableKey,
        merchantId: "acct_1JQbtnDFt4tW72zr",
        androidPayMode: 'test',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: ElevatedButton(
              onPressed: () {
                checkIfNativePayReady();
              },
              child: Text(txt))),
    );
  }

  void checkIfNativePayReady() async {
    print('started to check if native pay ready');
    bool? deviceSupportNativePay =
        await StripePayment.deviceSupportsNativePay();
    bool? isNativeReady = await StripePayment.canMakeNativePayPayments(
        ['american_express', 'visa', 'maestro', 'master_card']);
    deviceSupportNativePay! && isNativeReady!
        ? createPaymentMethodNative()
        : createPaymentMethod();
  }

  Future<void> createPaymentMethodNative() async {
    print('started NATIVE payment...');
    StripePayment.setStripeAccount("acct_1JQbtnDFt4tW72zr");
    List<ApplePayItem> items = [];
    items.add(ApplePayItem(
      label: 'Demo Order',
      amount: totalCost.toString(),
    ));
    if (tip != 0.0)
      items.add(ApplePayItem(
        label: 'Tip',
        amount: tip.toString(),
      ));
    if (taxPercent != 0.0) {
      tax = ((totalCost * taxPercent) * 100).ceil() / 100;
      items.add(ApplePayItem(
        label: 'Tax',
        amount: tax.toString(),
      ));
    }
    items.add(ApplePayItem(
      label: 'Vendor A',
      amount: (totalCost + tip + tax).toString(),
    ));
    amount = ((totalCost + tip + tax) * 100).toInt();
    print(
        'amount in pence/cent which will be charged = $amount'); //step 1: add card
    PaymentMethod? paymentMethod = PaymentMethod();
    Token token = await StripePayment.paymentRequestWithNativePay(
      androidPayOptions: AndroidPayPaymentRequest(
        totalPrice: (totalCost + tax + tip).toStringAsFixed(2),
        currencyCode: 'GBP',
      ),
      applePayOptions: ApplePayPaymentOptions(
        countryCode: 'GB',
        currencyCode: 'GBP',
        items: items,
      ),
    );
    paymentMethod = await StripePayment.createPaymentMethod(
      PaymentMethodRequest(
        card: CreditCard(
          token: token.tokenId,
          number: "4242424242424242",
          cvc: "123",
          expMonth: 5,
          expYear: 22,
        ),
      ),
    );
    print("paymentMethod==== $paymentMethod");
    paymentMethod != null
        ? processPaymentAsDirectCharge(paymentMethod)
        : showDialog(
            context: context,
            builder: (BuildContext context) => ShowDialogToDismiss(
                title: 'Error',
                content:
                    'It is not possible to pay with this card. Please try again with a different card',
                buttonText: 'CLOSE'));
  }

  Future<void> createPaymentMethod() async {
    StripePayment.setStripeAccount("acct_1JQbtnDFt4tW72zr");
    tax = ((totalCost * taxPercent) * 100).ceil() / 100;
    amount = ((totalCost + tip + tax) * 100).toInt();
    print(
        'amount in pence/cent which will be charged = $amount'); //step 1: add card
    PaymentMethod? paymentMethod;
    paymentMethod = await StripePayment.paymentRequestWithCardForm(
      CardFormPaymentRequest(
          /*prefilledInformation: PrefilledInformation.fromJson(
          {
            "number": "4242424242424242",
            "cvc": "123",
            "expMonth": 5,
            "expYear": 22,
          },
        ),*/
          ),
    ).then((PaymentMethod paymentMethod) {
      print("paymentMethod.type: ${paymentMethod.type}");
      return paymentMethod;
    }).catchError((e) {
      print('Errore Card: ${e.toString()}');
    });
    print("paymentMethod==== $paymentMethod");
    paymentMethod != null
        ? processPaymentAsDirectCharge(paymentMethod)
        : showDialog(
            context: context,
            builder: (BuildContext context) => ShowDialogToDismiss(
                title: 'Error',
                content:
                    'It is not possible to pay with this card. Please try again with a different card',
                buttonText: 'CLOSE'));
  }

  Future<void> processPaymentAsDirectCharge(PaymentMethod paymentMethod) async {
    setState(() {
      showSpinner = true;
    }); //step 2: request to create PaymentIntent, attempt to confirm the payment & return PaymentIntent
    final http.Response response = await http.post(
      Uri.parse(url),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: {
        "amount": amount.toString(),
        "currency": "GBP",
        "paym": paymentMethod.id
      },
      encoding: Encoding.getByName("utf-8"),
    );
    print(
        "http req = ${Uri.parse('$url?amount=$amount&currency=GBP&paym=${paymentMethod.id}')}");
    print('Now i decode');
    final paymentIntentX = jsonDecode(response.body);
    final strAccount = paymentIntentX['stripeAccount'];
    if (response.body != null && response.body != 'error') {
      final status = paymentIntentX['paymentIntent']['status'];
      if (status == 'succeeded') {
        //payment was confirmed by the server without need for futher authentification
        setState(() {
          txt = "payment succeeded";
        });
        StripePayment.completeNativePayRequest();
        setState(() {
          text =
              'Payment completed. ${paymentIntentX['paymentIntent']['amount'].toString()}p succesfully charged';
          showSpinner = false;
        });
      } else {
        //step 4: there is a need to authenticate
        StripePayment.setStripeAccount(strAccount);
        await StripePayment.confirmPaymentIntent(PaymentIntent(
                paymentMethodId: paymentIntentX['paymentIntent']
                    ['payment_method'],
                clientSecret: paymentIntentX['paymentIntent']['client_secret']))
            .then(
          (PaymentIntentResult paymentIntentResult) async {
            //This code will be executed if the authentication is successful
            //step 5: request the server to confirm the payment with
            final statusFinal = paymentIntentResult.status;
            if (statusFinal == 'succeeded') {
              setState(() {
                txt = "payment succeeded";
              });
              StripePayment.completeNativePayRequest();
              setState(() {
                showSpinner = false;
              });
            } else if (statusFinal == 'processing') {
              setState(() {
                txt = "processing";
              });
              StripePayment.cancelNativePayRequest();
              setState(() {
                showSpinner = false;
              });
              showDialog(
                  context: context,
                  builder: (BuildContext context) => ShowDialogToDismiss(
                      title: 'Warning',
                      content:
                          'The payment is still in \'processing\' state. This is unusual. Please contact us',
                      buttonText: 'CLOSE'));
            } else {
              setState(() {
                txt = "cancelled";
              });
              StripePayment.cancelNativePayRequest();
              setState(() {
                showSpinner = false;
              });
              showDialog(
                  context: context,
                  builder: (BuildContext context) => ShowDialogToDismiss(
                      title: 'Error',
                      content:
                          'There was an error to confirm the payment. Details: $statusFinal',
                      buttonText: 'CLOSE'));
            }
          },
          //If Authentication fails, a PlatformException will be raised which can be handled here
        ).catchError((e) {
          //case B1
          StripePayment.cancelNativePayRequest();
          setState(() {
            showSpinner = false;
          });
          showDialog(
              context: context,
              builder: (BuildContext context) => ShowDialogToDismiss(
                  title: 'Error',
                  content:
                      'There was an error to confirm the payment. Please try again with another card',
                  buttonText: 'CLOSE'));
        });
      }
    } else {
      setState(() {
        txt = "cancelled";
      });
      StripePayment.cancelNativePayRequest();
      setState(() {
        showSpinner = false;
      });
      showDialog(
          context: context,
          builder: (BuildContext context) => ShowDialogToDismiss(
              title: 'Error',
              content:
                  'There was an error in creating the payment. Please try again with another card',
              buttonText: 'CLOSE'));
    }
  }
}
