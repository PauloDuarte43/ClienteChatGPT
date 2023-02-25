import 'dart:convert';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class EngineOption {
  final String label;
  final String value;

  EngineOption(this.label, this.value);
}

List<EngineOption> _engineOptions = [
  EngineOption('Davinci', 'davinci'),
  EngineOption('Codex', 'codex'),
  EngineOption('Curie', 'curie'),
  EngineOption('Babbage', 'babbage'),
  EngineOption('Ada', 'ada'),
];

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatGPT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'ChatGPT'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  String _responseText = '';
  String _apiKey = "";
  String _sessionId = Uuid().v4();

  final ScrollController _scrollController = ScrollController();

  List<String> textList = ['Olá! Como posso ajudar?'];

  EngineOption _selectedEngine = _engineOptions.first;

  Future<void> _sendText() async {
    if (_apiKey.isEmpty) {
      // Show an alert dialog to inform the user that an API key is required
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Atualize a Chave de API"),
            content: Text(
                "Por favor, atualize sua chave da API para usar a API do ChatGPT\nEla pode ser gerada na página do chatGPT, https://platform.openai.com/account/api-keys"),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          );
        },
      );
      return;
    }

    final String prompt = _textController.text;

    if (prompt.isNotEmpty) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      FocusScope.of(context).requestFocus(new FocusNode());
      final String apiUrl =
          'https://api.openai.com/v1/engines/${_selectedEngine.value}/completions';
      _textController.clear();
      final String requestBody = json.encode({
        'prompt': prompt,
        'max_tokens': 60,
        'n': 1,
        'stop': ['\n']
      });
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $_apiKey",
        'Session-Id': _sessionId
      };
      final http.Response response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: requestBody);
      final Map<String, dynamic> responseData = json.decode(response.body);
      setState(() {
        try {
          textList.add(prompt);
          _responseText = responseData['choices'][0]['text'];
          textList.add(_responseText);
        } catch (e) {
          _responseText = responseData['error']['message'];
          textList.add(_responseText);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String apiKey = prefs.getString("api_key") ?? "";
    setState(() {
      _apiKey = apiKey;
    });
  }

  Future<void> _updateApiKey() async {
    final TextEditingController _apiKeyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update API Key"),
        content: TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: "Enter API key here",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final String apiKey = _apiKeyController.text;
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setString("api_key", apiKey);
              setState(() {
                _apiKey = apiKey;
              });
              Navigator.pop(context);
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: textList.length,
                itemBuilder: (BuildContext context, int index) {
                  String mensagem = textList[index];
                  bool isMinhaMensagem = index % 2 ==
                      0; // alternar entre mensagens minhas e do outro

                  return Container(
                    alignment: isMinhaMensagem
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMinhaMensagem ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TyperAnimatedTextKit(
                        text: [mensagem],
                        isRepeatingAnimation: false,
                        repeatForever: false,
                        totalRepeatCount: 1,
                        onFinished: () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      // child: Text(
                      //   mensagem,
                      //   style: TextStyle(
                      //       color:
                      //           isMinhaMensagem ? Colors.white : Colors.black),
                      // ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _textController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Digite seu texto aqui',
                ),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _sendText,
              child: Text('Enviar'),
            ),
            SizedBox(height: 16.0),
            DropdownButton<EngineOption>(
              value: _selectedEngine,
              onChanged: (EngineOption? option) {
                if (option != null) {
                  setState(() {
                    _selectedEngine = option;
                  });
                }
              },
              items: _engineOptions
                  .map<DropdownMenuItem<EngineOption>>((EngineOption option) {
                return DropdownMenuItem<EngineOption>(
                  value: option,
                  child: Text(option.label),
                );
              }).toList(),
            ),
            // Text(_responseText),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateApiKey,
        tooltip: "Update API Key",
        child: Icon(Icons.vpn_key),
      ),
    );
  }
}
