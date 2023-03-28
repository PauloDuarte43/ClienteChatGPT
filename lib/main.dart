import 'dart:async';
import 'dart:convert';

// import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() => runApp(const MyApp());

class EngineOption {
  final String label;
  final String value;

  EngineOption(this.label, this.value);
}

List<EngineOption> _engineOptions = [
  EngineOption('gpt-3.5-turbo', 'gpt-3.5-turbo'),
  EngineOption('gpt-3.5-turbo-0301', 'gpt-3.5-turbo-0301'),
  EngineOption('gpt-4', 'gpt-4'),
  EngineOption('gpt-4-0314', 'gpt-4-0314'),
  EngineOption('gpt-4-32k', 'gpt-4-32k'),
  EngineOption('gpt-4-32k-0314', 'gpt-4-32k-0314')
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
  late Map<String, dynamic> _response;
  bool _isLoading = false;
  bool _scrool = false;
  int tokens = 0;
  String _responseText = '';
  String _apiKey = "";
  final String _sessionId = const Uuid().v4();
  final Uri _url = Uri.parse('https://platform.openai.com/account/api-keys');

  final ScrollController _scrollController = ScrollController();
  Utf8Decoder decoder = const Utf8Decoder();

  Map<String, Map<String, dynamic>> models = {
    'gpt-3.5-turbo': {
      'description':
          'Most capable GPT-3.5 model and optimized for chat at 1/10th the cost of text-davinci-003. Will be updated with our latest model iteration.',
      'max_tokens': 4096
    },
    'gpt-3.5-turbo-0301': {
      'description':
          'Snapshot of gpt-3.5-turbo from March 1st 2023. Unlike gpt-3.5-turbo, this model will not receive updates, and will only be supported for a three month period ending on June 1st 2023',
      'max_tokens': 4096
    },
    'gpt-4': {
      'description':
          'More capable than any GPT-3.5 model, able to do more complex tasks, and optimized for chat. Will be updated with our latest model iteration.',
      'max_tokens': 8192
    },
    'gpt-4-0314': {
      'description':
          'Snapshot of gpt-4 from March 14th 2023. Unlike gpt-4, this model will not receive updates, and will only be supported for a three month period ending on June 14th 2023.',
      'max_tokens': 8192
    },
    'gpt-4-32k': {
      'description':
          'Same capabilities as the base gpt-4 mode but with 4x the context length. Will be updated with our latest model iteration.',
      'max_tokens': 32768
    },
    'gpt-4-32k-0314': {
      'description':
          'Snapshot of gpt-4-32 from March 14th 2023. Unlike gpt-4-32k, this model will not receive updates, and will only be supported for a three month period ending on June 14th 2023.',
      'max_tokens': 32768
    },
  };
  List<List<Map<String, dynamic>>> listChatGPTAssistant = [];
  List<Map<String, dynamic>> chatGPTAssistant = [
    {
      'role': 'assistant',
      'content':
          'Eu sou o assistente ChatGPT, estou aqui para responder qualquer pergunta!',
    },
  ];

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

  Future<void> _clearContext() async {
    await saveChatGPTAssistant();
    setState(() {
      chatGPTAssistant = [
        {
          'role': 'assistant',
          'content':
              'Eu sou o assistente ChatGPT, estou aqui para responder qualquer pergunta!',
        },
      ];
    });
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

      const String apiUrl = 'https://api.openai.com/v1/chat/completions';

      int maxTokens =
          selectedMaxTokens <= models[_selectedEngine.value]!['max_tokens']
              ? selectedMaxTokens
              : models[_selectedEngine.value]!['max_tokens'];

      _textController.clear();
      setState(() {
        _isLoading = true;
        _scrool = false;

        chatGPTAssistant.add(
          {
            'role': 'user',
            'content': prompt,
          },
        );
        Timer(const Duration(seconds: 1), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        });
      });
      late String requestBody;
      requestBody = json.encode({
        "model": _selectedEngine.value,
        'messages': chatGPTAssistant,
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
        _isLoading = false;
        try {
          _response = responseData['choices'][0];
          tokens = responseData['usage']['total_tokens'];
          finishReason = _response['finish_reason'];
          _responseText = _response['message']['content'];
          _responseText = decoder.convert(_responseText.codeUnits);

          chatGPTAssistant.add({
            'role': 'assistant',
            'content': _responseText,
          });
          Timer(const Duration(seconds: 1), () {
            // Animar a posição do scroll para o final da lista
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        } catch (e) {
          try {
            _responseText = responseData['error']['message'];
            showPopUp('Ops!!!', _responseText);
          } catch (e) {
            _responseText = '$e';
            showPopUp('Erro desconhecido!', _responseText);
          }
        }
      });
    }
  }

  void showPopUp(String title, String body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
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
  }

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    loadChatGPTAssistant();
  }

  @override
  void dispose() {
    saveChatGPTAssistant();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String apiKey = prefs.getString("api_key") ?? "";
    setState(() {
      _apiKey = apiKey;
    });
  }

  Future<void> saveChatGPTAssistant() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    listChatGPTAssistant.add(chatGPTAssistant);
    final String json = jsonEncode(listChatGPTAssistant);
    await prefs.setString('listChatGPTAssistant', json);
  }

  Future<void> loadChatGPTAssistant() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String json = prefs.getString('listChatGPTAssistant') ?? '[]';
    final List<dynamic> jsonList = jsonDecode(json);
    listChatGPTAssistant = jsonList
        .map<List<Map<String, dynamic>>>(
            (json) => List<Map<String, dynamic>>.from(json))
        .toList();
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
                          itemCount: chatGPTAssistant.length,
                          itemBuilder: (BuildContext context, int index) {
                            Map<String, dynamic> mensagem =
                                chatGPTAssistant[index];
                            bool isMinhaMensagem =
                                mensagem['role'] == 'assistant';

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
                                        child: md.MarkdownBody(
                                          data: mensagem['content'],
                                        ),
                                        // child: AnimatedTextKit(
                                        //   animatedTexts: [
                                        //     TypewriterAnimatedText(
                                        //       mensagem['content'],
                                        //     ),
                                        //   ],
                                        //   totalRepeatCount: 1,
                                        //   isRepeatingAnimation: false,
                                        //   repeatForever: false,
                                        //   onFinished: () {
                                        //     if (!_scrool) {
                                        //       _scrollController.animateTo(
                                        //         _scrollController
                                        //             .position.maxScrollExtent,
                                        //         duration: const Duration(
                                        //             milliseconds: 500),
                                        //         curve: Curves.easeOut,
                                        //       );
                                        //       setState(() {
                                        //         _scrool = true;
                                        //       });
                                        //     }
                                        //   },
                                        // ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () {
                                        // código a ser executado quando o botão é pressionado
                                        // if (Platform.isIOS || Platform.isAndroid) {
                                        Clipboard.setData(ClipboardData(
                                            text: mensagem['content']));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          duration: Duration(seconds: 1),
                                          content: Text(
                                              'Texto copiado para a área de transferência'),
                                        ));
                                        // } else {}
                                      },
                                    ),
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
                                  8192,
                                  32768
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
                              Text(
                                'Tokens: $tokens',
                                style: const TextStyle(fontSize: 10.0),
                              ),
                              Text(finishReason),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _sendText,
                                    child: const Text('Enviar'),
                                  ),
                                  IconButton(
                                    iconSize: 16.0,
                                    icon: const Icon(Icons.delete),
                                    onPressed: _clearContext,
                                  ),
                                  _isLoading
                                      ? const Center(
                                          child: SpinKitCircle(
                                            color: Colors.blue,
                                            size: 15.0,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ],
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Center(
                  child: Text(
                    'Histórico de Conversas',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25.0),
                  ),
                ),
              ),
              for (var item in listChatGPTAssistant)
                if (item.length > 1)
                  ListTile(
                    title: Text(item[1]['content'].length >= 15
                        ? item[1]['content'].substring(0, 15)
                        : item[1]['content']),
                    leading: const Icon(Icons.history_edu_outlined),
                    onTap: () {
                      saveChatGPTAssistant();
                      setState(() {
                        chatGPTAssistant = item;
                        listChatGPTAssistant.remove(item);
                      });
                      Navigator.pop(context);
                    },
                  ),
            ],
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
