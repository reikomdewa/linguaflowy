import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConstants {
  static bool hasUserPaid = false;
  static int userXp = 0;
  static int userCoins = 0;
  static dynamic userData;

  static List<Map<String, dynamic>> users = [];
  static fetchDataFromFirestore() async {
    if (FirebaseAuth.instance.currentUser != null) {
      final user = FirebaseAuth.instance.currentUser!;
      CollectionReference users =
          FirebaseFirestore.instance.collection('users');

      QuerySnapshot usersSnapshot = await users.get();
      for (var doc in (usersSnapshot as dynamic).docs) {
        var data = doc.data();
        bool hasPaid;
        if (data['email'] == user.email) {
          ///future change this
          if (data['hasPaid'] == null) {
            hasPaid = false;
          } else {
            hasPaid = data['hasPaid'].toLowerCase() == 'true';
          }
          hasUserPaid = hasPaid;
          userXp = data['xp'];
          userCoins = data['coins'];
          userData = data;
          break;
        }
      }
    }
  }

  static String? priceDuration;
  static String? price;
  static dynamic appData;
  static String? pricePer;
  static fetchAppData() async {
    if (FirebaseAuth.instance.currentUser != null) {
      final user = FirebaseAuth.instance.currentUser!;

      CollectionReference appDataCollection =
          FirebaseFirestore.instance.collection('app_data');
      QuerySnapshot appDataSnapshot = await appDataCollection.get();

      for (var doc in (appDataSnapshot as dynamic).docs) {
        var data = doc.data();
        //  print(data);
        appData = data;
        // print(appData);
        bool hasPaid;
        if (data['email'] == user.email) {
          ///future change this
          if (data['hasPaid'] == null) {
            hasPaid = false;
          } else {
            hasPaid = data['hasPaid'].toLowerCase() == 'true';
          }
          hasUserPaid = hasPaid;
          priceDuration = data['duration'];
          price = data['price'];
          // print(data);

          break;
        }
      }
    }
  }

  static void updateXpsAndCoins(bool isDone, bool isNotSpam) async {
    final user = FirebaseAuth.instance.currentUser!;
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    QuerySnapshot snapshot = await users.get();

    for (var doc in (snapshot as dynamic).docs) {
      var data = doc.data();

      int newXp = data['xp'] + 1;
      if (data['email'] == user.email) {
        if (isDone && isNotSpam) {
          // data.update({'xp': newXp.toString()});
          await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .update({'xp': newXp});
          // if (newXp > 100) {
          //   await FirebaseFirestore.instance
          //       .collection('users')
          //       .doc(doc.id)
          //       .update({'coins': newCoins.toString()});
          // }
          if (newXp >= 100 && newXp % 100 == 0) {
            // int newCoins = data['coins'] + 1;
            int newCoins = data['coins'] + 1;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(doc.id)
                .update({'coins': newCoins});
          }
        }
        userCoins = data['coins'];
        break;
      }
    }
  }

  static void updateTheme(bool changedTheme) async {
    final user = FirebaseAuth.instance.currentUser!;
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    QuerySnapshot snapshot = await users.get();

    for (var doc in (snapshot as dynamic).docs) {
      var data = doc.data();

      if (data['email'] == user.email) {
        // data.update({'xp': newXp.toString()});
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .update({'is_user_theme_light': !changedTheme});
        // if (newXp > 100) {
        //   await FirebaseFirestore.instance
        //       .collection('users')
        //       .doc(doc.id)
        //       .update({'coins': newCoins.toString()});
        // }

        break;
      }
    }
  }

  static void getUsersByXp() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('xp',
            descending: true) // Order users by 'xp' in descending order
        .get();
    users = querySnapshot.docs
        .map((doc) => doc.data())
        .toList()
        .cast<Map<String, dynamic>>();

    // for (var doc in (snapshot as dynamic).docs) {
    //   var data = doc.data();
    // }
  }
}
