    // if (!isPremium) {
    //             showDialog(
    //               context: context,
    //               builder: (context) => LayoutBuilder(
    //                 builder: (context, constraints) {
    //                   bool isDesktop = constraints.maxWidth > 600;
    //                   return isDesktop
    //                       ? CenteredView(
    //                           horizontalPadding: 500,
    //                           child: PremiumLockDialog(onClose: () {}),
    //                         )
    //                       : PremiumLockDialog(onClose: () {});
    //                 },
    //               ),
    //             ).then((unlocked) {
    //               if (unlocked == true && context.mounted) {
    //                 context.read<AuthBloc>().add(AuthCheckRequested());
    //                 ScaffoldMessenger.of(context).showSnackBar(
    //                   const SnackBar(
    //                     content: Text("Welcome to Premium!"),
    //                     backgroundColor: Colors.green,
    //                   ),
    //                 );
    //               }
    //             });
    //           } else {
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               const SnackBar(
    //                 content: Text(
    //                   "You are a PRO member!",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //                 backgroundColor: Colors.amber,
    //                 duration: Duration(seconds: 1),
    //               ),
    //             );
    //           }