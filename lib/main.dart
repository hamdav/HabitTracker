// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'dart:math';

enum HabitAction { rename, editCategories, removeLastCheck, delete, }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to Flutter'),
        ),
        body: const HabitsCheckerWidget(),
      ),
    );
  }
}

class HabitsCheckerWidget extends StatefulWidget {
	const HabitsCheckerWidget({super.key});

	@override
    State<HabitsCheckerWidget> createState() => _HabitsCheckerWidgetState();
}

class _HabitsCheckerWidgetState extends State<HabitsCheckerWidget> {

	final List<Habit> _habits = [];
	final _biggerFont = const TextStyle(fontSize: 18);

	@override
	Widget build(BuildContext context) {

		HabitAction? menuSelection;

		var habitWidgets = _habits.map(
			(h) => ListTile(
				title: Text(h.name,
					style: _biggerFont,
				),
				subtitle: Text(h.checks.toString()),
				leading: const Icon(
					Icons.check_circle,
					color: Colors.green,
					semanticLabel: 'Do',
					size: 40
				  ),
				onTap: () {
					setState(() {h.check();});
				},
				onLongPress: () {
					showDatePicker(
						initialDate: DateTime.now(),
						firstDate: DateTime.utc(1979,1,1),
						lastDate: DateTime.utc(3000,1,1),
						context: context,
					).then((date) => setState(()=> h.check(date)));
				},
				trailing: PopupMenuButton<HabitAction>(
					initialValue: menuSelection,
					itemBuilder: (context) =>
						<PopupMenuEntry<HabitAction>>[
							const PopupMenuItem<HabitAction>(
								value: HabitAction.rename,
								child: Text('Rename'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.editCategories,
								child: Text('Edit categories'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.removeLastCheck,
								child: Text('Remove last check'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.delete,
								child: Text('Delete',
									style: TextStyle(
										fontWeight: FontWeight.bold,
										color: Colors.red)),
							),
						],
					onSelected: (HabitAction selection) {
						setState(() {
							switch (selection) {
								case HabitAction.delete:
									// TODO: Confirm?
									_habits.remove(h);
									break;
								case HabitAction.rename:
									_displayTextInputDialog(context, "Rename", "New name")
										.then((newName) {h.name = newName ?? h.name;});
									break;
								default: //TODO: Fix
									print("HI");
							}
						});
						},
					),
				)
			).toList();

		return Scaffold(
			body: ListView(
					children: habitWidgets
				),
			floatingActionButton: FloatingActionButton(
				child: const Icon(Icons.add),
				onPressed: () {
					_displayTextInputDialog(context, "Name of habit", "Name")
						.then((name) {
							if (name != null) {
								setState(() {_habits.add(Habit(name)); });
							}
						});
				},
			),
		);
		}
	Future<String?> _displayTextInputDialog(BuildContext context, String title, String hint) async {
		/*
		 * Shows a popup with input and returns the user input if
		 * they pressed OK, otherwise it returns null
		 */
		String? tmpText;
		String? returnText;
		await showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: Text(title),
					content: TextField(
						onChanged: (value) {
							setState(() { tmpText = value; });
						},
						decoration: InputDecoration(hintText: hint),
					),
					actions: <Widget>[
						TextButton(
							child: const Text('CANCEL'),
							onPressed: () {
								setState(() {
									returnText = null;
									Navigator.pop(context);
								});
							},
						),
						TextButton(
							child: const Text('OK'),
							onPressed: () {
								setState(() {
									returnText = tmpText;
									Navigator.pop(context);
								});
							},
						),
					],
				);
			}
		);
		return returnText;
	}
}

class Habit {
	late String name;
	Set<Habit> categories = {};
	late List<DateTime> checks = [];

	Habit(this.name);

	void check([DateTime? d]) {
		checks.add(d ?? DateTime.now());
	}

	// TODO: Remove category
	void addCategory(Habit cat) {
		categories.add(cat);
	}
}

