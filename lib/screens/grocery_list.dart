import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/screens/new_item.dart';
import 'package:http/http.dart' as http;

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() {
    return _GroceryListState();
  }
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItem = []; //groceryItems;
  String? _error;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadItem();
  }

  void loadItem() async {
    final url = Uri.https(
      'flutter-shopping-list-c00a1-default-rtdb.firebaseio.com',
      'shopping-list.json',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch data. Please try again later.!';
        });
      }

      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> resData = jsonDecode(response.body);
      final List<GroceryItem> loadedItem = [];

      for (final item in resData.entries) {
        final loadedCategory = categories.entries
            .firstWhere((e) => e.value.title == item.value['category'])
            .value;

        loadedItem.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: loadedCategory,
          ),
        );

        setState(() {
          _groceryItem = loadedItem;
          _isLoading = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Something went wrong! Please try again later.';
      });
    }
  }

  void undoDelete(GroceryItem item) async {
    final url = Uri.https(
      'flutter-shopping-list-c00a1-default-rtdb.firebaseio.com',
      'shopping-list.json',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        {
          'name': item.name,
          'quantity': item.quantity,
          'category': item.category.title,
        },
      ),
    );

    setState(() {
      loadItem();
    });

    print('undo action response --- ${response.statusCode}');

    if (!context.mounted) {
      return;
    }
  }

  void showSnackBarMessage(
      int indexValue, GroceryItem item, String msg, bool actionNeeded) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        elevation: 2,
        behavior: SnackBarBehavior.floating,
        action: actionNeeded
            ? SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  undoDelete(item);
                  // setState(() {
                  //   _groceryItem.insert(indexValue, item);
                  // });

                  showSnackBarMessage(
                      indexValue, item, 'Item added to list', false);
                },
              )
            : SnackBarAction(
                label: '',
                onPressed: () {},
              ),
      ),
    );
  }

  void onRemove(GroceryItem item) async {
    final indexValue = _groceryItem.indexOf(item);
    setState(() {
      _groceryItem.remove(item);
    });

    print('item.id -- ${item.id}');
    final url = Uri.https(
      'flutter-shopping-list-c00a1-default-rtdb.firebaseio.com',
      'shopping-list/${item.id}.json',
    );

    final response = await http.delete(url);
    print('deletion response.statusCode - ${response.statusCode}');

    if (response.statusCode >= 400) {
      showSnackBarMessage(
        indexValue,
        item,
        'Something wrong. Item not removed!',
        false,
      );
      setState(() {
        _groceryItem.insert(indexValue, item);
      });
    }
    if (response.statusCode == 200) {
      showSnackBarMessage(
        indexValue,
        item,
        'Item removed from list!',
        true,
      );
    }
  }

  // void newItems() async {
  //   final addedGroceryItem = await Navigator.of(context).push<GroceryItem>(
  //     MaterialPageRoute(
  //       builder: (ctx) => const NewItem(),
  //     ),
  //   );

  //   if(addedGroceryItem == null) {
  //     return;
  //   }

  //   setState(() {
  //     _groceryItem.add(addedGroceryItem);
  //   });
  // }

  void newItems() async {
    final addedGroceryItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => const NewItem(),
      ),
    );

    if (addedGroceryItem == null) {
      return;
    }

    setState(() {
      _groceryItem.add(addedGroceryItem);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(
      child: Text('No item added yet!'),
    );

    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      content = Center(
        child: Text(_error!),
      );
    }

    if (_groceryItem.isNotEmpty) {
      content = ListView.builder(
        itemCount: _groceryItem.length,
        itemBuilder: (ctx, index) => Dismissible(
          key: ValueKey(_groceryItem[index].id),
          onDismissed: (direction) {
            onRemove(_groceryItem[index]);
          },
          child: ListTile(
            leading: Container(
              height: 20,
              width: 20,
              color: _groceryItem[index].category.color,
            ),
            title: Text(_groceryItem[index].name),
            trailing: Text(
              _groceryItem[index].quantity.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: newItems,
              icon: const Icon(Icons.add),
            ),
          ],
          title: const Text('Your Groceries'),
        ),
        body: content);
  }
}
