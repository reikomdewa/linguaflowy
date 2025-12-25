import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 1. IMPORT YOUR NEW BLOCS & EVENTS
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';

import 'package:linguaflow/screens/speak/widgets/views/speak_view.dart';

class SpeakScreen extends StatelessWidget {
  const SpeakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. USE MultiBlocProvider INSTEAD OF BlocProvider
    return MultiBlocProvider(
      providers: [
        // Initialize Room Logic (starts the stream immediately)
        BlocProvider<RoomBloc>(
          create: (context) => RoomBloc()..add(const LoadRooms()),
        ),
        // Initialize Tutor Logic (fetches profiles once)
        BlocProvider<TutorBloc>(
          create: (context) => TutorBloc()..add(const LoadTutors()),
        ),
      ],
      child: const SpeakView(),
    );
  }
}