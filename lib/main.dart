// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

enum HabitAction { rename, addCategory, removeCategory, removeLastCheck, delete, }

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

	List<Habit> _habits = [];
	Set<String> getCategories() => _habits.map((h) => h.categories)
		.reduce((r, cats) => r.union(cats));
	final _biggerFont = const TextStyle(fontSize: 18);

	@override
	initState() {
		print("Loading");
		_loadHabitsFromFiles();
		super.initState();
	}

	@override
	Widget build(BuildContext context) {

		HabitAction? menuSelection;

		_habits.sort((h1, h2) {
			if (h1.checks.isEmpty && h2.checks.isEmpty) {
				return 0;
			} else if (h1.checks.isEmpty) {
				return 1;
			} else if (h2.checks.isEmpty) {
				return -1;
			} else {
				return h2.checks.last.compareTo(h1.checks.last);
			}});
		var habitWidgets = _habits.map(
			(h) => ListTile(
				title: Text(h.name,
					style: _biggerFont,
				),
				subtitle: Text("Last check: ${h.checks.isEmpty ? '-' : timeago.format(h.checks.last)}\nCategories: ${h.categories.join(', ')}"),
				leading: const Icon(
					Icons.check_circle,
					color: Colors.green,
					semanticLabel: 'Do',
					size: 40
				  ),
				onTap: () {
					setState(() {
						h.check();
						_saveHabitsToFiles();
					});
				},
				onLongPress: () {
					showDatePicker(
						initialDate: DateTime.now(),
						firstDate: DateTime.utc(1979,1,1),
						lastDate: DateTime.utc(3000,1,1),
						context: context,
					).then((date) => setState(() {
						h.check(date);
						_saveHabitsToFiles();
					}));
				},
				trailing: PopupMenuButton<HabitAction>(
					initialValue: menuSelection,
					itemBuilder: (context) =>
						<PopupMenuEntry<HabitAction>>[
							const PopupMenuItem<HabitAction>(
								value: HabitAction.removeLastCheck,
								child: Text('Remove last check'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.rename,
								child: Text('Rename'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.addCategory,
								child: Text('Add category'),
							),
							const PopupMenuItem<HabitAction>(
								value: HabitAction.removeCategory,
								child: Text('Remove category'),
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
								case HabitAction.removeLastCheck:
									h.removeLastCheck();
									break;
								case HabitAction.delete:
									_displayConfirmDialog(context, "Delete ${h.name}", "This action cannot be undone").then((rv) {
										if (rv) {
											_habits.remove(h);
										}
									});
									break;
								case HabitAction.rename:
									_displayTextInputDialog(context, "Rename", "New name")
										.then((newName) {h.name = newName ?? h.name;});
									break;
								case HabitAction.addCategory:
									_displayAutocompleteDialog(context, "Add category", getCategories())
										.then((String? cat) {
											if (cat != null) {
												h.addCategory(cat);
											}
										});
									break;
								case HabitAction.removeCategory:
									_displayAutocompleteDialog(context, "Remove category", h.categories)
										.then((String? cat) {
											if (cat != null) {
												h.removeCategory(cat);
											}
										});
									break;
							}
							_saveHabitsToFiles();
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
								setState(() {
									_habits.add(Habit(name));
									_saveHabitsToFiles();
								});
							}
						});
				},
			),
		);
	}

	Future<void> _saveHabitsToFiles() async {
		final directory = await getApplicationDocumentsDirectory();

		for (Habit h in _habits) {
			final path = directory.path;
			final filename = "${h.name}.habit.csv";
			File f = File('$path/$filename');
			f.writeAsString(h.toCsvString());
			print("Wrote $path/$filename");
		}
	}

	Future<void> _loadHabitsFromFiles() async {
		final directory = await getApplicationDocumentsDirectory();

		final files = directory.list();

		_habits = [];
		await for (FileSystemEntity f in files) {
			if (f is! File) {
				continue;
			}
			if (!f.path.endsWith(".habit.csv")) {
				continue;
			}
			print("Reading ${f.path}");
			final csvString = await f.readAsString();
			_habits.add(Habit.fromCsvString(csvString));
		}

		setState((){});
	}

	Future<bool> _displayConfirmDialog(BuildContext context, String title, String body) async {
		/*
		 * Shows a popup with input and returns the user input if
		 * they pressed OK, otherwise it returns null
		 */
		bool rv = false;
		await showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: Text(title),
					content: Text(body),
					actions: <Widget>[
						TextButton(
							child: const Text('CANCEL'),
							onPressed: () {
								setState(() {
									rv = false;
									Navigator.pop(context);
								});
							},
						),
						TextButton(
							child: const Text('OK'),
							onPressed: () {
								setState(() {
									rv = true;
									Navigator.pop(context);
								});
							},
						),
					],
				);
			}
		);
		return rv;
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
	Future<String?> _displayAutocompleteDialog(BuildContext context, String title, Set<String> options) async {
		/*
		 * Shows a popup with input and returns the user input if
		 * they pressed OK, otherwise it returns null.
		 */
		String? tmpOption;
		String? returnOption;
		await showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: Text(title),
					content: Autocomplete<String>(
						optionsBuilder: (TextEditingValue textEditingValue) {
							var filteredOptions = options.where((String s) =>
									s.toLowerCase().contains(textEditingValue.text.toLowerCase())
								).toList();
							filteredOptions.add(textEditingValue.text);
							return filteredOptions;
						},
						onSelected: (String s) {
							setState(() { tmpOption = s; });
						},
					),
					actions: <Widget>[
						TextButton(
							child: const Text('CANCEL'),
							onPressed: () {
								setState(() {
									returnOption = null;
									Navigator.pop(context);
								});
							},
						),
						TextButton(
							child: const Text('OK'),
							onPressed: () {
								setState(() {
									returnOption = tmpOption;
									Navigator.pop(context);
								});
							},
						),
					],
				);
			}
		);
		return returnOption;
	}
}

class Habit {
	late String name;
	Set<String> categories = {};
	List<DateTime> checks = [];

	Habit(this.name);

	Habit.fromCsvString(String csvString) {
		final nameIndexBegin = csvString.indexOf("name: ") + 6;
		final nameIndexEnd = csvString.substring(nameIndexBegin).indexOf("\n") + nameIndexBegin;
		final catIndexBegin = csvString.indexOf("categories: ") + 12;
		final catIndexEnd = csvString.substring(catIndexBegin).indexOf("\n") + catIndexBegin;

		name = csvString.substring(nameIndexBegin, nameIndexEnd)
			.trim();
		categories = csvString.substring(catIndexBegin, catIndexEnd)
			.split(",")
			.map((s) => s.trim())
			.toSet();
		if (csvString.substring(catIndexEnd).isEmpty) {
			checks = [];
		} else {
			checks = csvString.split('\n')
				.where((line) => !line.startsWith('#') && line != "")
				//.map((dateString) => DateTime.parse(dateString))
				.map((dateString) {print("Datestring: $dateString\n"); return DateTime.parse(dateString);})
				.toList();
		}
	}

	String toCsvString() {
		return "# name: $name\n" + "# categories: "
			+ categories.join(", ")
			+ "\n"
			+ checks.map((date) => date.toString())
				.join("\n");
	}

	static Future<List<Habit>> habitsFromFiles(List<File> files) async {
		/*
		 * Takes a list of files objects and returns a habit for each
		 * file. Categories are resolved last and any categories not
		 * present will be ignored.
		 */

		// Read files
		final contents = files.map((file) => file.readAsString());

		// Create habits, ignoring categories for now.
		var habits = Future.wait(
			contents.map((futureCsvString) =>
				futureCsvString.then((csvString) =>
					Habit.fromCsvString(csvString))));

		return habits;

	}

	void check([DateTime? d]) {
		checks.add(d ?? DateTime.now());
	}

	void removeLastCheck() {
		if (!checks.isEmpty) {
			checks.removeLast();
		}
	}

	void addCategory(String cat) {
		categories.add(cat);
	}
	void removeCategory(String cat) {
		categories.remove(cat);
	}
}

