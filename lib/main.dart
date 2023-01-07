import 'dart:io';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:path_provider/path_provider.dart';
import 'package:graphic/graphic.dart';
import 'package:intl/intl.dart';

enum HabitAction { rename, addCategory, removeCategory, removeLastCheck, delete, }
final _monthDayFormat = DateFormat.MMMd();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Habit Checker',
      home: HabitsCheckerWidget(),
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
									_displayAutocompleteDialog(context, "Add category", Habit.getCategories(_habits))
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
			appBar: AppBar(
			  title: const Text('Habit Checker'),
			  actions: [
				  IconButton(
					icon: const Icon(Icons.list),
					onPressed: _showStats,
					tooltip: 'See statistics',
				  ),
				],
			),
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

	void _showStats() {
		Navigator.of(context).push(
			MaterialPageRoute<void>(
				builder: (context) {
					return StatsPage(habits: _habits);
				}
			)
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
			.where((s) => s != "")
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
	static Set<String> getCategories(List<Habit> habits) =>
		habits.map((h) => h.categories)
		.reduce((r, cats) => r.union(cats));

	void check([DateTime? d]) {
		checks.add(d ?? DateTime.now());
	}

	void removeLastCheck() {
		if (checks.isNotEmpty) {
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

class StatsPage extends StatefulWidget {

	List<Habit> habits;
	StatsPage({super.key, required List<Habit> this.habits});

	@override
    State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {

	Map<String, bool> selectedCategories = {};
	Map<Habit, bool> selectedHabits = {};
	DateTime startDate = DateTime.now().subtract(Duration(days:7));
	DateTime endDate = DateTime.now();
	HistogramBins histBins = HistogramBins.day;

	void _showSelectionScreen() {

		var result = Navigator.push(
			context,
			MaterialPageRoute(builder: (context) {
				return SelectionScreen(
					habits: widget.habits,
					s: Selection(selectedHabits: selectedHabits,
						selectedCategories: selectedCategories),
				);
			}),
		).then((selection){setState((){
			selectedCategories = selection.selectedCategories;
			selectedHabits = selection.selectedHabits;
		});});
	}

	@override
	initState() {
		for (Habit h in widget.habits) {
			selectedHabits[h] = true;
			for (String cat in h.categories) {
				selectedCategories[cat] = false;
			}
		}
		super.initState();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text("Stats"),
			),
			body: SingleChildScrollView(
				child: Center(
				  child: Column(
				children: <Widget>[
				  Container(
					padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
					child: const Text(
					  'Stacked Bar Chart',
					  style: TextStyle(fontSize: 20),
					),
				  ),
				  Container(
					padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
					child: Row(
						children: <Widget>[
							TextButton(
							  child: Text('Start date'),
							  onPressed: () {showDatePicker(
								initialDate: startDate,
								firstDate: DateTime.utc(1979,1,1),
								lastDate: DateTime.utc(3000,1,1),
								context: context,
							  ).then((date) => setState(() {
								if (date != null) {
									startDate = date;
								}
								}));
							},),
							TextButton(
							  child: Text('End date'),
							  onPressed: () {showDatePicker(
								initialDate: endDate,
								firstDate: DateTime.utc(1979,1,1),
								lastDate: DateTime.utc(3000,1,1),
								context: context,
							  ).then((date) => setState(() {
								if (date != null) {
									endDate = date;
								}
								}));
							},),
							TextButton(
							  child: Text('Selection'),
							  onPressed: () {
								_showSelectionScreen();
							  },
							),
							PopupMenuButton<HistogramBins>(
								child: Text("Bin size",
									style: TextStyle(
										fontWeight: FontWeight.w500,
										color: Colors.blue,
									),
								),
								initialValue: histBins,
								itemBuilder: (context) =>
									<PopupMenuEntry<HistogramBins>>[
										const PopupMenuItem<HistogramBins>(
											value: HistogramBins.day,
											child: Text('one day'),
										),
										const PopupMenuItem<HistogramBins>(
											value: HistogramBins.week,
											child: Text('one week'),
										),
										const PopupMenuItem<HistogramBins>(
											value: HistogramBins.month,
											child: Text('one month'),
										),
										const PopupMenuItem<HistogramBins>(
											value: HistogramBins.year,
											child: Text('one year'),
										),
									],
								onSelected: (HistogramBins selection) {
									setState(() {
										histBins = selection;
									});
								},
							),
							],
						),
				  ),
				  Container(
					margin: const EdgeInsets.only(top: 10),
					width: 350,
					height: 300,
					child: HistogramWidget(habits: widget.habits.where((h) => selectedHabits[h]! || h.categories.any((cat) => selectedCategories[cat]!)).toList(),
						histBins: histBins, startDate: startDate, endDate: endDate),
				  ),
				  Container(
					padding: const EdgeInsets.fromLTRB(10, 25, 10, 0),
					alignment: Alignment.centerLeft,
					child: const Text(
					  'Cool stats fact no 1',
					),
				  ),
				  Container(
					padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
					alignment: Alignment.centerLeft,
					child: const Text(
					  'Cool stats fact no 2',
					),
				  )
				],
			),
			),
			),
			);
	}
}

class HistogramWidget extends StatelessWidget {

	final List<Habit> habits;
	HistogramBins histBins;
	late DateTime startDate;
	late DateTime endDate;
	late List<Map> data;
	int maxCount = 0;

	HistogramWidget({super.key, required this.habits, required this.histBins, required this.startDate, required this.endDate});

	void binTheData() {
		/*
		 * bin is a verb
		 */
		print("Binnin");
		data = [];
		late DateTime d;
		switch (histBins) {
			case HistogramBins.day:
				d = DateTime(endDate.year, endDate.month, endDate.day);
				break;
			case HistogramBins.week:
				// The latest monday (yes negative days are allowed in the
				// DateTime constructor)
				d = DateTime(endDate.year, endDate.month, endDate.day-(endDate.weekday-1));
				break;
			case HistogramBins.month:
				d = DateTime(endDate.year, endDate.month, 1);
				break;
			case HistogramBins.year:
				d = DateTime(endDate.year, 1, 1);
				break;
		}
		List<int> habitChecksIndex = List.filled(habits.length, 0);
		List<String> habitNames = habits.map((h) => h.name).toList();
		List<List<DateTime>> habitSortedChecks = habits.map((h) {
			//final sortedChecks = h.checks.where(
				//(d) => d.isAfter(startDate) && d.isBefore(endDate)
			//).toList();
			final sortedChecks = h.checks;
			// Sort in reverse chronological order
			sortedChecks.sort((d1, d2) => d2.compareTo(d1));
			return sortedChecks;
		}).toList();
		bool firstLoop = true;
		while (true) { // d update loop
			bool done = false;
			int totalCount = 0;
			for (int habitIdx = 0; habitIdx < habitNames.length; habitIdx++) {
				int count = 0;
				while (habitChecksIndex[habitIdx] < habitSortedChecks[habitIdx].length) {
					final DateTime checkDate = habitSortedChecks[habitIdx][habitChecksIndex[habitIdx]];
					if (checkDate.isAfter(d)) {
						count++;
						habitChecksIndex[habitIdx]++;
					} else {
						break;
					}
				}
				data.add({'date': d, 'habit': habitNames[habitIdx], 'count': count});
				totalCount += count;
				if (totalCount > maxCount) {
					maxCount = totalCount;
				}
				//if (habitChecksIndex[habitIdx] < habitSortedChecks[habitIdx].length) {
					//done = false;
				//}
				if (d.isBefore(startDate)) {
					done = true;
				}
			}
			// There must be two dates at least...
			if (done && !firstLoop) {
				break;
			}
			firstLoop = false;
			switch (histBins) {
				case HistogramBins.day:
					d = d.subtract(const Duration(days: 1));
					break;
				case HistogramBins.week:
					d = d.subtract(const Duration(days: 7));
					break;
				case HistogramBins.month:
					d = DateTime(d.year, d.month-1, d.day);
					break;
				case HistogramBins.year:
					d = DateTime(d.year-1, d.month, d.day);
					break;
			}
		}
		data = data.reversed.toList();
		print(data);
	}

	@override
	Widget build(BuildContext context) {
		binTheData();

		if (data.length > 0) {

			List<Annotation> legend = [];
			final int n = habits.length;
			for (int i=0; i < n; i++) {
				Habit h = habits[i];
				legend.add(
                    MarkAnnotation(
                      relativePath: Path()
                        ..addRect(Rect.fromCircle(
                            center: const Offset(0, 0), radius: 5)),
                      style: Paint()..color = Defaults.colors10[i],
                      anchor: (size) => Offset(25 + i*size.width / n, size.height+10),
                    ),
				);
				legend.add(
                    TagAnnotation(
                      label: Label(
                        h.name,
                        LabelStyle(
                            style: Defaults.textStyle,
                            align: Alignment.centerRight),
                      ),
                      anchor: (size) => Offset(34 + i*size.width / n, size.height+10),
                    ),
				);
			}
			return Chart(
			  data: data,
			  variables: {
				'date': Variable(
				  accessor: (Map map) => _monthDayFormat.format(map['date']) as String,
				  scale: OrdinalScale(tickCount: 5),
				  //accessor: (Map map) => map['date'] as DateTime,
				  //scale: TimeScale(
					 //formatter: (date) => _monthDayFormat.format(date),
				  //),
				),
				'habit': Variable(
				  accessor: (Map map) => map['habit'] as String,
				),
				'count': Variable(
				  accessor: (Map map) => map['count'] as num,
				  scale: LinearScale(min: 0, max: maxCount),
				),
			  },
			  elements: [
				IntervalElement(
				  position:
					  Varset('date') * Varset('count') / Varset('habit'),
				  shape: ShapeAttr(value: RectShape(histogram: true)),
				  color: ColorAttr(
					  variable: 'habit', values: Defaults.colors10),
				  //label: LabelAttr(
					  //encoder: (tuple) => Label(
							//tuple['count'].toString(),
							//LabelStyle(style: const TextStyle(fontSize: 6)),
						  //)),
				  modifiers: [StackModifier()],
				)
			  ],
			  axes: [
				Defaults.horizontalAxis,
				Defaults.verticalAxis,
			  ],
			  selections: {
				'tap': PointSelection(
				  variable: 'date',
				)
			  },
			  tooltip: TooltipGuide(multiTuples: true),
			  //crosshair: CrosshairGuide(),
			  annotations: legend,
			);
		} else {
			return Center(child: Text("No habits selected"));
		}
	}
}

class SelectionScreen extends StatefulWidget {
	List<Habit> habits;
	Selection s;
	
	SelectionScreen({super.key, required this.habits, required this.s});

	@override
    State<SelectionScreen> createState() => _SelectionScreenState();
	
}

class Selection {
	Map<String, bool> selectedCategories;
	Map<Habit, bool> selectedHabits;

	Selection({required this.selectedHabits, required this.selectedCategories});
}

class _SelectionScreenState extends State<SelectionScreen> {

	Map<Habit, bool> habitMask = {};

	@override
	initState() {
		for (Habit h in widget.habits) {
			habitMask[h] = widget.s.selectedHabits[h]!;
		}
	}


	@override
	Widget build(BuildContext context) {

		for (Habit h in widget.habits) {
			if (h.categories.any((cat) => widget.s.selectedCategories[cat]!)) {
				habitMask[h] = true;
			} else {
				habitMask[h] = false;
			}
		}

		var habitCheckboxes = widget.habits.map((Habit h) {
			return CheckboxListTile(
				title: Text(h.name),
				value: habitMask[h]! || widget.s.selectedHabits[h]!,
				enabled: !habitMask[h]!,
				tristate: false,
				onChanged: (bool? value) {
					setState(() {
						widget.s.selectedHabits[h] = value!;
					});
				},
			);
		}).toList();

		var catCheckboxes = Habit.getCategories(widget.habits)
			.map((String cat) {
				return CheckboxListTile(
					title: Text(cat),
					tristate: false,
					value: widget.s.selectedCategories[cat],
					onChanged: (bool? value) {
						setState(() {
							widget.s.selectedCategories[cat] = value!;
						});
					}
				);
			}).toList();

		return WillPopScope(
			child: Scaffold(
				appBar: AppBar(
					title: Text("Select habits"),
				),
				body: ListView(
					children: habitCheckboxes + catCheckboxes,
				),
			),
			onWillPop: () async {
				Navigator.pop(context, widget.s);
				return false;
			}
		);
	}
}
enum HistogramBins { day, week, month, year }
