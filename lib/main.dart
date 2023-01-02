// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'dart:math';

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
        body: const Center(
          child: RandomNumber(),
        ),
      ),
    );
  }
}

class RandomNumber extends StatefulWidget {
	const RandomNumber({super.key});

	@override
    State<RandomNumber> createState() => _RandomNumberState();
}

class _RandomNumberState extends State<RandomNumber> {

	final List<int> _numbers = [];
	Iterable<int> _rndGenerator(Random rng) sync* {
		yield rng.nextInt(100);
	}
	final _biggerFont = const TextStyle(fontSize: 18);

	@override
	Widget build(BuildContext context) {
		final rng = Random();
		return ListView.builder(
			padding: const EdgeInsets.all(16.0),
			itemBuilder: (context, i) {
				if (i.isOdd) return const Divider();

				final index = i ~/ 2;
				if (index >= _numbers.length) {
					_numbers.addAll(_rndGenerator(rng).take(10));
				}
				return ListTile(
					title: Text(_numbers[index].toString(),
						style: _biggerFont,
					),
					trailing: Icon(    // NEW from here ...
						Icons.check_circle,
						color: Colors.green,
						semanticLabel: 'Do',
						size: 40
					  ),
				);
			},
		);
	}
}

