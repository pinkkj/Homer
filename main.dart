import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
List<int> view = [0];
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _pageIndex = 0;
  List<String> keywords = [];
  List<String> subscribeList = [];
  Map<String, String> scrappedNews = {};

  @override
  void initState() {
    super.initState();
    fetchKeywords(); 
    fetchsubscribes();
  }
  Future<void> fetchsubscribes() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5000/get_subscribes'));
    if (response.statusCode == 200) {
      final List<dynamic> subscribeData = jsonDecode(response.body)['keywords'];
      setState(() {
        subscribeList = List<String>.from(subscribeData);
      });
    } else {
      throw Exception('Failed to load subscribeData');
    }
  }

  Future<void> fetchKeywords() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5000/get_keywords'));
    if (response.statusCode == 200) {
      final List<dynamic> keywordsData = jsonDecode(response.body)['keywords'];
      setState(() {
        keywords = List<String>.from(keywordsData);
      });
    } else {
      throw Exception('Failed to load keywords');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _pageIndex = index;
    });
  }

  Future<void> addKeyword(String keyword) async {
    var url = Uri.parse('http://10.0.2.2:5000/add_keyword');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({'keyword': keyword});

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Keyword added successfully.');
    } else {
      print('Failed to add keyword: ${response.body}');
    }
  }

  Future<void> removeKeyword(String keyword) async {
    var url = Uri.parse('http://10.0.2.2:5000/remove_keyword');
    var response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'keyword': keyword}));

    if (response.statusCode == 200) {
      print('Keyword removed successfully.');
    } else {
      print('Failed to remove keyword: ${response.body}');
    }
  }

  Future<void> addSubscribe(String channel) async {
    var url = Uri.parse('http://10.0.2.2:5000/add_subscribe');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({'subscribe': channel});

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        subscribeList.add(channel); 
      });
      print('Subscribed to $channel');
    } else {
      print('Failed to add subscribe: ${response.body}');
    }
  }

  Future<void> removeSubscribe(String channel) async {
    var url = Uri.parse('http://10.0.2.2:5000/remove_subscribe');
    var response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'subscribe': channel}));

    if (response.statusCode == 200) {
      setState(() {
        subscribeList.remove(channel); 
      });
      print('Unsubscribed from $channel');
    } else {
      print('Failed to remove subscribe: ${response.body}');
    }
  }
  
  void _addSubscribe() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newChannel = '';
        return AlertDialog(
          title: const Text('Add Subscribe'),
          content: TextField(
            onChanged: (value) {
              newChannel = value;
            },
            decoration: const InputDecoration(hintText: "Enter a channel"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Subscribe'),
              onPressed: () {
                setState(() {
                  if (newChannel.isNotEmpty) {
                    addSubscribe(newChannel);
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeSubscribe() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Subscribe'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: subscribeList.length, 
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(subscribeList[index]), 
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        removeSubscribe(subscribeList[index]);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _addKeyword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newKeyword = '';
        return AlertDialog(
          title: const Text('Add Keyword'),
          content: TextField(
            onChanged: (value) {
              newKeyword = value;
            },
            decoration: const InputDecoration(hintText: "Enter a keyword"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                setState(() {
                  if (newKeyword.isNotEmpty) {
                    keywords.add(newKeyword);
                    addKeyword(newKeyword);
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _editKeywords() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Keywords'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: keywords.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(keywords[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        removeKeyword(keywords[index]);
                        keywords.removeAt(index);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homer'),
        centerTitle: true,
        elevation: 6,
        actions: _pageIndex == 0
            ? <Widget>[
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.black87,
                  ),
                  onPressed: _addKeyword,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.black87,
                  ),
                  onPressed: _editKeywords,
                ),
              ]
            : _pageIndex == 2
                ? <Widget>[
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.black87,
                      ),
                      onPressed: _addSubscribe,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.black87,
                      ),
                      onPressed: _removeSubscribe,
                    ),
                  ]
                : null,
      ),
      body: IndexedStack(
  index: _pageIndex,
  children: <Widget>[
    Center(
      child: keywords.isNotEmpty
          ? ListView.builder(
              itemCount: keywords.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(keywords[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsScreen(
                          keyword: keywords[index],
                          scrappedNews: scrappedNews,
                          onScrapAdd: addScrap,
                          onScrapRemove: removeScrap,
                          onAddMemo: addMemo,
                        ),
                      ),
                    );
                  },
                );
              },
            )
          : const Text('No keywords added', style: TextStyle(fontSize: 20)),
    ),
    ScrapPage(scrappedNews: scrappedNews, onAddMemo: addMemo),
    Center(
      child: subscribeList.isNotEmpty
          ? ListView.builder(
              itemCount: subscribeList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(subscribeList[index]),
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubscribeNewsPage(subscribe: subscribeList[index]),
                      ),
                    );
                  },
                );
              },
            )
          : const Text('No keywords added', style: TextStyle(fontSize: 20)),
    ),
    MyPage(), 
  ],
),
      bottomNavigationBar: BottomNavigationBar(
  onTap: _onItemTapped,
  currentIndex: _pageIndex,
  selectedItemColor: Colors.amber,
  unselectedItemColor: Colors.black26,
  items: const <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.mail_outline), 
      activeIcon: Icon(Icons.mail), 
      label: 'inbox',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.crop_original_outlined), 
      activeIcon: Icon(Icons.crop_original), 
      label: 'scrap',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.subscriptions_outlined), 
      activeIcon: Icon(Icons.subscriptions), 
      label: 'subscribe',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline), 
      activeIcon: Icon(Icons.person), 
      label: 'mypage',
    ),
  ],
),
    );
  }


  void addScrap(String title, String link, String keyword, int keyNumber) async {
    var url = Uri.parse('http://10.0.2.2:5000/scrap_news');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({
      'title': title,
      'link': link,
      'keyword': keyword,
      'key_number': keyNumber.toString(),
    });

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        scrappedNews[title] = link;
      });
      print('Scrap added successfully.');
    } else {
      print('Failed to add scrap: ${response.body}');
    }
  }

  void removeScrap(String title, int keyNumber) async {
    var url = Uri.parse('http://10.0.2.2:5000/remove_scrap_news');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({'title': title});

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        scrappedNews.remove(title);
      });
      print('Scrap removed successfully.');
    } else {
      print('Failed to remove scrap: ${response.body}');
    }
  }

  Future<void> addMemo(String title, String memo) async {
    var url = Uri.parse('http://10.0.2.2:5000/add_memo');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({'title': title, 'memo': memo});

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Memo added successfully.');
    } else {
      print('Failed to add memo: ${response.body}');
    }
  }
}

class NewsScreen extends StatefulWidget {
  final String keyword;
  final Map scrappedNews;
  final void Function(String, String, String, int) onScrapAdd;
  final void Function(String, int) onScrapRemove;
  final void Function(String, String) onAddMemo;

  const NewsScreen({
    Key? key,
    required this.keyword,
    required this.scrappedNews,
    required this.onScrapAdd,
    required this.onScrapRemove,
    required this.onAddMemo,
  }) : super(key: key);

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<String> newsTitles = [];
  List<String> newsLinks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5000/get_news?keyword=${widget.keyword}'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<String> titles = List<String>.from(responseData['titles']);
      final List<String> links = List<String>.from(responseData['links']);
      setState(() {
        newsTitles = titles;
        newsLinks = links;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load news: ${response.body}');
    }
  }

  void toggleScrap(String title, String link, int keyNumber) {
  setState(() {
    if (widget.scrappedNews.containsKey(title)) {
      widget.onScrapRemove(title, keyNumber);
      widget.scrappedNews.remove(title); 
    } else {
      widget.onScrapAdd(title, link, widget.keyword, keyNumber);
      widget.scrappedNews[title] = link; 
    }
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('News for ${widget.keyword}'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : newsTitles.isEmpty
              ? Center(
                  child: Text('No news found for ${widget.keyword}'),
                )
              : ListView.builder(
                  itemCount: newsTitles.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(newsTitles[index]),
                      trailing: IconButton(
                        icon: Icon(
                          widget.scrappedNews.containsKey(newsTitles[index])
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: widget.scrappedNews.containsKey(newsTitles[index])
                              ? Colors.amber
                              : null,
                        ),
                        onPressed: () {
                          toggleScrap(newsTitles[index], newsLinks[index], index);
                        },
                      ),
                      onTap: () async {
                        String url = newsLinks[index];
                        Uri uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class ScrapPage extends StatelessWidget {
  final Map<String, String> scrappedNews;
  final void Function(String, String) onAddMemo;

  const ScrapPage({Key? key, required this.scrappedNews, required this.onAddMemo}) : super(key: key);

  void _addMemo(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoPage(
          newsTitle: title,
          onAddMemo: onAddMemo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrap Page'),
      ),
      body: scrappedNews.isEmpty
          ? const Center(
              child: Text('No scrapped news', style: TextStyle(fontSize: 20)),
            )
          : ListView.builder(
              itemCount: scrappedNews.length,
              itemBuilder: (context, index) {
                String title = scrappedNews.keys.elementAt(index);
                return ListTile(
                  title: Text(title),
                  trailing: IconButton(
                    icon: const Icon(Icons.note_add),
                    onPressed: () {
                      _addMemo(context, title);
                    },
                  ),
                  onTap: () async {
                    String url = scrappedNews[title]!;
                    Uri uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
 else {
                      throw 'Could not launch $url';
                    }
                  },
                );
              },
            ),
    );
  }
}

class MemoPage extends StatefulWidget {
  final String newsTitle;
  final void Function(String, String) onAddMemo;

  const MemoPage({Key? key, required this.newsTitle, required this.onAddMemo}) : super(key: key);

  @override
  _MemoPageState createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  String _memo = '';
  List<String> memos = [];

  @override
  void initState() {
    super.initState();
    fetchMemos();
  }

  Future<void> fetchMemos() async {
    var url = Uri.parse('http://10.0.2.2:5000/get_memos?news_id=${widget.newsTitle}');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      setState(() {
        memos = List<String>.from(data.map((item) => item['memo']));
      });
    } else {
      print('Failed to load memos: ${response.body}');
    }
  }

  void removeMemo(String memo) async {
    var url = Uri.parse('http://10.0.2.2:5000/remove_memo');
    var headers = {'Content-Type': 'application/json'};
    var body = jsonEncode({'news_id': widget.newsTitle, 'memo': memo});

    var response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      setState(() {
        memos.remove(memo);
      });
      print('Memo removed successfully.');
    } else {
      print('Failed to remove memo: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Memo for ${widget.newsTitle}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: memos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(memos[index]),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Delete Memo'),
                            content: Text('Are you sure you want to delete this memo?'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: Text('Delete'),
                                onPressed: () {
                                  removeMemo(memos[index]);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      _memo = value;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter a memo',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (_memo.isNotEmpty) {
                      widget.onAddMemo(widget.newsTitle, _memo);
                      setState(() {
                        memos.add(_memo);
                        _memo = '';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubscribeNewsPage extends StatefulWidget {
  final String subscribe;
  SubscribeNewsPage({required this.subscribe});


  @override
  _SubscribeNewsPageState createState() => _SubscribeNewsPageState();
}

class _SubscribeNewsPageState extends State<SubscribeNewsPage> {
  List<dynamic>? _newsList;
  bool _isLoading = true;
  List<String> subscribeList = [];

  @override
  void initState() {
    super.initState();
    _fetchSubscribeNews();
  }

  Future<void> _fetchSubscribeNews() async {
    var url = Uri.parse('http://10.0.2.2:5000/get_subscribe_news?subscribe=${widget.subscribe}');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        _newsList = jsonDecode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      print('Failed to load subscribe news: ${response.body}');
    }
  }

  void _launchArticle(String link) async {
    Uri uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $link';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscribe News: ${widget.subscribe}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
  itemCount: _newsList?.length ?? 0,
  itemBuilder: (context, index) {
    Color backgroundColor = _newsList?[index]['view'].toInt() > view[0] ? Colors.green : Colors.transparent;
    int viewsText = _newsList?[index]['view'];
    viewsText.toString();
    return Container(
      color: backgroundColor, 
      child: ListTile(
        leading: Text(_newsList?[index]['ranking'] ?? ''), 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_newsList?[index]['title'] ?? ''),
            Text("View: $viewsText"),
          ],
        ),
        onTap: () {
          _launchArticle(_newsList?[index]['link'] ?? '');
        },
      ),
    );
  },
),
    );
  }
}
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  int _minViews = 0;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMaxViews();
  }
  Future<int> getMaxViews() async {
  final response = await http.get(Uri.parse('http://10.0.2.2:5000/get_views'));

  if (response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);
    return int.parse(jsonResponse['view'][0]);
  } else {
    throw Exception('Failed to load max views');
  }
}
Future<void> setMaxViews(int maxViews) async {
  final response = await http.post(
    Uri.parse('http://10.0.2.2:5000/set_views'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, int>{'max_views': maxViews}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to set max views');
  }
}


  Future<void> _fetchMaxViews() async {
    try {
      final maxViews = await getMaxViews();
      setState(() {
        _minViews = maxViews;
        _controller.text = _minViews.toString();
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _updateminViews() async {
    final newMaxViews = int.tryParse(_controller.text);
    if (newMaxViews != null) {
      try {
        view[0] = newMaxViews;
        await setMaxViews(newMaxViews);
        setState(() {
          _minViews = newMaxViews;
        });
      } catch (e) {
        print(e);
      }
    } else {
      print('Invalid input');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Page'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Current max views: $_minViews'),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Set new max views'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _updateminViews,
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
