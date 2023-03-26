import 'dart:convert';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class EngineOption {
  final String label;
  final String value;

  EngineOption(this.label, this.value);
}

List<EngineOption> _engineOptions = [
  EngineOption('Davinci 3', 'text-davinci-003'),
  EngineOption('Davinci 2', 'text-davinci-002'),
  EngineOption('Curie', 'text-curie-001'),
  EngineOption('Babbage', 'text-babbage-001'),
  EngineOption('Ada', 'text-ada-001'),
  EngineOption('Davinci', 'davinci'),
  EngineOption('Curie', 'curie'),
  EngineOption('Babbage', 'babbage'),
  EngineOption('Ada', 'ada'),
  EngineOption('gpt-3.5-turbo', 'gpt-3.5-turbo'),
  EngineOption('gpt-4', 'gpt-4')
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatGPT',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const MyHomePage(title: 'ChatGPT'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  String _responseText = '';
  String _apiKey = "";
  final String _sessionId = const Uuid().v4();
  final Uri _url = Uri.parse('https://platform.openai.com/account/api-keys');

  final ScrollController _scrollController = ScrollController();
  Utf8Decoder decoder = const Utf8Decoder();

  Map<String, Map<String, dynamic>> models = {
    'text-davinci-003': {
      'description':
          'O modelo mais poderoso e versátil do ChatGPT, adequado para várias tarefas, incluindo geração de texto, tradução de idiomas, resumo de texto e muito mais.',
      'max_tokens': 4097
    },
    'gpt-4': {'description': 'gpt-4.', 'max_tokens': 8192},
    'gpt-3.5-turbo': {'description': 'gpt-3.5-turbo.', 'max_tokens': 4096},
    'text-davinci-002': {
      'description':
          'Uma versão anterior do modelo Davinci que ainda está disponível para fins de compatibilidade, mas é menos poderosa do que a versão atual.',
      'max_tokens': 4096
    },
    'text-curie-001': {
      'description':
          'Um modelo menor e mais rápido que o Davinci, mas ainda capaz de gerar texto coerente e útil.',
      'max_tokens': 2048
    },
    'text-babbage-001': {
      'description':
          'Um modelo menor do que o Curie, adequado para tarefas mais simples de geração de texto.',
      'max_tokens': 1024
    },
    'text-ada-001': {
      'description':
          'Um modelo menor e mais rápido do que o Babbage, adequado para tarefas básicas de geração de texto.',
      'max_tokens': 1024
    },
    'davinci': {
      'description':
          'O modelo mais poderoso e versátil do ChatGPT, adequado para várias tarefas, incluindo geração de texto, tradução de idiomas, resumo de texto e muito mais.',
      'max_tokens': 2048
    },
    'curie': {
      'description':
          'Um modelo menor e mais rápido que o Davinci, mas ainda capaz de gerar texto coerente e útil.',
      'max_tokens': 2048
    },
    'babbage': {
      'description':
          'Um modelo menor do que o Curie, adequado para tarefas mais simples de geração de texto.',
      'max_tokens': 1024
    },
    'ada': {
      'description':
          'Um modelo menor e mais rápido do que o Babbage, adequado para tarefas básicas de geração de texto.',
      'max_tokens': 1024
    }
  };

  List<String> textList = ['Olá! Como posso ajudar?'];

  int selectedMaxTokens = 200;
  String finishReason = "";

  EngineOption _selectedEngine = _engineOptions.first;

  Future<void> _launchUrl(url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Não foi possível abrir $url');
    }
  }

  Future<void> _sendText() async {
    if (_apiKey.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Atualize a Chave de API"),
            content: RichText(
              text: TextSpan(
                text:
                    'Por favor, atualize sua chave da API para usar a API do ChatGPT. Ela pode ser gerada na página do chatGPT: ',
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(
                    text: _url.toString(),
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchUrl(_url);
                      },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("OK"),
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
      FocusScope.of(context).requestFocus(FocusNode());
      const String apiUrl = 'https://api.openai.com/v1/completions';
      // 'https://api.openai.com/v1/engines/${_selectedEngine.value}/completions';
      int maxTokens =
          selectedMaxTokens <= models[_selectedEngine.value]!['max_tokens']
              ? selectedMaxTokens
              : models[_selectedEngine.value]!['max_tokens'];
      _textController.clear();
      final String requestBody = json.encode({
        "model": _selectedEngine.value,
        'prompt': prompt,
        'max_tokens': maxTokens,
        'n': 1
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
          finishReason = responseData['choices'][0]['finish_reason'];
          _responseText = decoder.convert(_responseText.codeUnits);
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
    final TextEditingController apiKeyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atualizar chave de API"),
        content: TextField(
          controller: apiKeyController,
          decoration: const InputDecoration(
            hintText: "Insira a chave da API aqui",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final String apiKey = apiKeyController.text;
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setString("api_key", apiKey);
              setState(() {
                _apiKey = apiKey;
              });
              Navigator.pop(context);
            },
            child: const Text("Atualizar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
          color: const Color.fromARGB(255, 97, 97, 97),
          child: Center(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Container(
                  color: const Color.fromARGB(255, 212, 255, 171),
                  width: MediaQuery.of(context).size.width > 600
                      ? 600
                      : MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: textList.length,
                          itemBuilder: (BuildContext context, int index) {
                            String mensagem = textList[index];
                            bool isMinhaMensagem = index % 2 == 0;

                            return Container(
                              alignment: isMinhaMensagem
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isMinhaMensagem
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: isMinhaMensagem
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width -
                                                120,
                                        child: AnimatedTextKit(
                                          animatedTexts: [
                                            TypewriterAnimatedText(
                                              mensagem,
                                            ),
                                          ],
                                          totalRepeatCount: 1,
                                          isRepeatingAnimation: false,
                                          repeatForever: false,
                                          onFinished: () {
                                            _scrollController.animateTo(
                                              _scrollController
                                                  .position.maxScrollExtent,
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    isMinhaMensagem
                                        ? IconButton(
                                            icon: const Icon(Icons.copy),
                                            onPressed: () {
                                              // código a ser executado quando o botão é pressionado
                                              // if (Platform.isIOS || Platform.isAndroid) {
                                              Clipboard.setData(ClipboardData(
                                                  text: mensagem));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                duration: Duration(seconds: 1),
                                                content: Text(
                                                    'Texto copiado para a área de transferência'),
                                              ));
                                              // } else {}
                                            },
                                          )
                                        : const SizedBox.shrink()
                                  ],
                                ),
                                // IconButton(
                                //           icon: const Icon(Icons.copy),
                                //           onPressed: () {
                                //             // código a ser executado quando o botão é pressionado
                                //             // if (Platform.isIOS || Platform.isAndroid) {
                                //             Clipboard.setData(
                                //                 ClipboardData(text: mensagem));
                                //             ScaffoldMessenger.of(context)
                                //                 .showSnackBar(const SnackBar(
                                //               duration: Duration(seconds: 1),
                                //               content: Text(
                                //                   'Texto copiado para a área de transferência'),
                                //             ));
                                //             // } else {}
                                //           },
                                //         )
                                // child: TyperAnimatedTextKit(
                                //   text: [mensagem],
                                //   isRepeatingAnimation: false,
                                //   repeatForever: false,
                                //   totalRepeatCount: 1,
                                //   onFinished: () {
                                //     _scrollController.animateTo(
                                //       _scrollController
                                //           .position.maxScrollExtent,
                                //       duration:
                                //           const Duration(milliseconds: 500),
                                //       curve: Curves.easeOut,
                                //     );
                                //   },
                                // ),
                                // child: Text(
                                //   mensagem,
                                //   style: TextStyle(
                                //       color: isMinhaMensagem
                                //           ? Colors.white
                                //           : Colors.black),
                                // ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300.0,
                          ),
                          child: TextField(
                            controller: _textController,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Digite seu texto aqui',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Modelo',
                                style: TextStyle(fontSize: 10.0),
                              ),
                              DropdownButton<EngineOption>(
                                value: _selectedEngine,
                                onChanged: (EngineOption? option) {
                                  if (option != null) {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text(
                                              'Você selecionou o modelo ${option.label}'),
                                          content: Text(models[option.value]![
                                              'description']),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Fechar'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    setState(() {
                                      _selectedEngine = option;
                                    });
                                  }
                                },
                                items: _engineOptions
                                    .map<DropdownMenuItem<EngineOption>>(
                                        (EngineOption option) {
                                  return DropdownMenuItem<EngineOption>(
                                    value: option,
                                    child: Text(option.label),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Max. Tokens',
                                style: TextStyle(fontSize: 10.0),
                              ),
                              DropdownButton<int>(
                                value: selectedMaxTokens,
                                onChanged: (value) {
                                  setState(() {
                                    selectedMaxTokens = value!;
                                  });
                                },
                                items: <int>[
                                  50,
                                  80,
                                  100,
                                  150,
                                  200,
                                  400,
                                  600,
                                  800,
                                  1600,
                                  2048,
                                  4096,
                                  8192
                                ].map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(finishReason),
                              ElevatedButton(
                                onPressed: _sendText,
                                child: const Text('Enviar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Text(_responseText),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton: Stack(
          children: [
            Positioned(
              right: 16,
              top: 16,
              child: FloatingActionButton(
                onPressed: _updateApiKey,
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.blueAccent,
                tooltip: "Atualizar chave de API",
                child: const Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
