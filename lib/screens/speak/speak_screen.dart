import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
import 'package:linguaflow/screens/speak/widgets/views/speak_view.dart';

class SpeakScreen extends StatelessWidget {
  const SpeakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RoomBloc>(
          create: (context) => RoomBloc()..add(const LoadRooms()),
        ),
        BlocProvider<TutorBloc>(
          create: (context) => TutorBloc()..add(const LoadTutors()),
        ),
      ],
      // This calls the Tab View below
      child: const SpeakView(),
    );
  }
}