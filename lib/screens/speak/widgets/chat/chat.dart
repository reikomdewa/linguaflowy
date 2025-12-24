// import 'package:cross_cache/cross_cache.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_chat_core/flutter_chat_core.dart';
// import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
// import 'package:flutter_chat_ui/flutter_chat_ui.dart'; // Required for ChatTheme, DarkChatTheme, etc.
// import 'package:intl/intl.dart'; // Required for DateFormat
// import 'package:provider/provider.dart';

// // INTERNAL IMPORTS (These must exist in your project folder)


// /// The main widget that orchestrates the chat UI.
// class Chat extends StatefulWidget {
//   final String currentUserId;
//   final ResolveUserCallback resolveUser;
//   final ChatController chatController;
//   final Builders? builders;
//   final CrossCache? crossCache;
//   final UserCache? userCache;
//   final ChatTheme? theme;
//   final OnMessageSendCallback? onMessageSend;
//   final OnMessageTapCallback? onMessageTap;
//   final OnMessageLongPressCallback? onMessageLongPress;
//   final OnMessageSecondaryTapCallback? onMessageSecondaryTap;
//   final OnAttachmentTapCallback? onAttachmentTap;
//   final Color? backgroundColor;
//   final Decoration? decoration;
//   final DateFormat? timeFormat;

//   const Chat({
//     super.key,
//     required this.currentUserId,
//     required this.resolveUser,
//     required this.chatController,
//     this.builders,
//     this.crossCache,
//     this.userCache,
//     this.theme,
//     this.onMessageSend,
//     this.onMessageTap,
//     this.onMessageLongPress,
//     this.onMessageSecondaryTap,
//     this.onAttachmentTap,
//     this.backgroundColor,
//     this.decoration,
//     this.timeFormat,
//   });

//   @override
//   State<Chat> createState() => _ChatState();
// }

// class _ChatState extends State<Chat> with WidgetsBindingObserver {
//   late ChatTheme _theme;
//   late Builders _builders;
//   late final CrossCache _crossCache;
//   late final UserCache _userCache;
//   late DateFormat _timeFormat;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _updateTheme();
//     _updateBuilders();
//     _crossCache = widget.crossCache ?? CrossCache();
//     _userCache = widget.userCache ?? UserCache(maxSize: 100);
//     _timeFormat = widget.timeFormat ?? DateFormat('HH:mm');
//   }

//   @override
//   void didUpdateWidget(covariant Chat oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (oldWidget.theme != widget.theme) {
//       _updateTheme();
//     }

//     if (oldWidget.builders != widget.builders) {
//       _updateBuilders();
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     if (widget.crossCache == null) {
//       _crossCache.dispose();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         Provider.value(value: widget.currentUserId),
//         Provider.value(value: widget.resolveUser),
//         Provider.value(value: widget.chatController),
//         Provider.value(value: _theme),
//         Provider.value(value: _builders),
//         Provider.value(value: _crossCache),
//         if (widget.userCache != null)
//           ChangeNotifierProvider.value(value: _userCache)
//         else
//           ChangeNotifierProvider(create: (_) => _userCache),
//         Provider.value(value: _timeFormat),
//         Provider.value(value: widget.onMessageSend),
//         Provider.value(value: widget.onMessageTap),
//         Provider.value(value: widget.onMessageLongPress),
//         Provider.value(value: widget.onMessageSecondaryTap),
//         Provider.value(value: widget.onAttachmentTap),
//         ChangeNotifierProvider(create: (_) => ComposerHeightNotifier()),
//         ChangeNotifierProvider(create: (_) => LoadMoreNotifier()),
//       ],
//       child: Container(
//         color: widget.decoration != null
//             ? null
//             : (widget.backgroundColor ?? _theme.colors.background),
//         decoration: widget.decoration,
//         child: Stack(
//           children: [
//             _builders.chatAnimatedListBuilder?.call(context, _buildItem) ??
//                 ChatAnimatedList(itemBuilder: _buildItem),
//             _builders.composerBuilder?.call(context) ?? const Composer(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildItem(
//     BuildContext context,
//     types.Message message,
//     int index,
//     Animation<double> animation, {
//     MessagesGroupingMode? messagesGroupingMode,
//     int? messageGroupingTimeoutInSeconds,
//     bool? isRemoved,
//   }) {
//     return ChatMessageInternal(
//       key: ValueKey(message.id),
//       message: message,
//       index: index,
//       animation: animation,
//       messagesGroupingMode: messagesGroupingMode,
//       messageGroupingTimeoutInSeconds: messageGroupingTimeoutInSeconds,
//       isRemoved: isRemoved,
//     );
//   }

//   void _updateTheme() {
//     _theme = widget.theme ?? const DefaultChatTheme();
//   }

//   void _updateBuilders() {
//     _builders = widget.builders ?? const Builders();
//   }
// }