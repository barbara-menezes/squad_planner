import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:squad_planner/screens/database_helper.dart';
import 'package:squad_planner/screens/signing_screen.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String translate_title = 'Translation';
  String translate_description = 'Translation';
  final formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _datasController = TextEditingController();
  final TextEditingController _participantesController =
      TextEditingController();
  var myData = [];

  String? validateMyTextField(String? value) {
    if (value!.isEmpty) return 'Field is Required';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _refreshData(); // Loading the data when the app starts
  }

  _refreshData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userEvents = await DatabaseHelper.getItems(user.uid);
      final participantEvents =
          await DatabaseHelper.getParticipantEvents(user.uid);
      final data = [...userEvents, ...participantEvents];

      setState(() {
        myData = data;
      });
    }
  }

  Future<void> addItem() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await DatabaseHelper.createItem(
          _titleController.text,
          _descriptionController.text,
          _enderecoController.text,
          _horarioController.text,
          _datasController.text,
          _participantesController.text,
          user.uid,
          0);
      _refreshData();
    }
  }

  Future<void> updateItem(int id) async {
    await DatabaseHelper.updateItem(
      id,
      _titleController.text,
      _descriptionController.text,
      _enderecoController.text,
      _horarioController.text,
      _datasController.text,
      _participantesController.text,
    );
    _refreshData();
  }

  Future<void> deleteItem(int id) async {
    await DatabaseHelper.deleteItem(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Evento deletado com sucesso"),
      backgroundColor: Colors.green,
    ));
    _refreshData();
  }

  static Future<void> printUsers() async {
    final users = await DatabaseHelper.getUsers();
    print("Users in SQLite: $users");
  }

  void _showEventDetails(int index) {
    if (index < 0 || index >= myData.length) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var event = myData[index];
        var title = event['title'] ?? 'N/A';
        var description = event['description'] ?? 'N/A';
        var endereco = event['endereco'] ?? 'N/A';
        var horario = event['horario'] ?? 'N/A';
        var datas = event['datas'] ?? 'N/A';

        var confirmations = event['confirmations'];
        var confirmationsCount =
            (confirmations != null && confirmations is List)
                ? confirmations.length.toString()
                : '0';

        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Detalhes do Evento',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.0),
                _buildDetailItem('Título', title),
                _buildDetailItem('Descrição', description),
                _buildDetailItem('Endereço', endereco),
                _buildDetailItem('Horário', horario),
                _buildDetailItem('Data', datas),
                _buildDetailItem('Confirmados', confirmationsCount),
                _buildConfirmationButton(event['id'], index),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 5.0),
        Text(
          value,
          style: TextStyle(fontSize: 16.0),
        ),
        SizedBox(height: 10.0),
      ],
    );
  }

  Widget _buildConfirmationButton(int eventId, int index) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && myData[index]['userId'] != user.uid) {
      return ElevatedButton(
        onPressed: () async {
          await _confirmAttendance(eventId, index);

          // Atualizar a interface do usuário
          setState(() {});

          // Fechar o modal
          Navigator.pop(context);
        },
        child: Text('Confirme sua presença'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xff274D76),
          foregroundColor: Colors.white,
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Future<void> _confirmAttendance(int eventId, int index) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final existingData =
          myData.firstWhere((element) => element['id'] == eventId);

      // Adicione prints para depurar
      print('existingData[\'confirmados\']: ${existingData['confirmados']}');

      // Verifique o tipo do campo confirmados
      if (existingData['confirmados'] is int) {
        int confirmados = existingData['confirmados'] as int;

        // Verifique se o usuário já confirmou presença
        if (confirmados == 0) {
          // Crie um novo mapa com os dados atualizados
          Map<String, dynamic> updatedData = Map.from(existingData);
          updatedData['confirmados'] = confirmados + 1;

          // Atualize a confirmação no banco de dados
          await DatabaseHelper.confirmAttendance(eventId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Presença confirmada com sucesso"),
              backgroundColor: Colors.green,
            ),
          );

          // Atualize a lista local e a interface do usuário
          setState(() {
            myData[index] = updatedData;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Você já confirmou presença"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Se o campo confirmados não estiver presente ou não for do tipo int
        // Trate isso como um valor inicial de 1
        // Crie um novo mapa com os dados atualizados
        Map<String, dynamic> updatedData = Map.from(existingData);
        updatedData['confirmados'] = 1;

        // Atualize a confirmação no banco de dados
        await DatabaseHelper.confirmAttendance(eventId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Presença confirmada com sucesso"),
            backgroundColor: Colors.green,
          ),
        );

        // Atualize a lista local e a interface do usuário
        setState(() {
          myData[index] = updatedData;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xff274D76),
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Opções do Menu'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.exit_to_app),
                          title: Text('Sair'),
                          onTap: () {
                            FirebaseAuth.instance.signOut().then(((value) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SignInScreen()));
                            }));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        title: Center(
          child: Text(
            'SQUAD-PLANNER',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
      body: myData.isEmpty
          ? Center(
              child: Text(
                "NENHUM EVENTO CADASTRADO",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.grey,
                ),
              ),
            )
          : Column(
              children: [
                // ElevatedButton(
                //   onPressed: () async {
                //     await printUsers();
                //   },
                //   child: Text('Mostrar Usuários'),
                // ),
                Padding(
                  padding: const EdgeInsets.all(9.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Eventos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.notifications,
                        size: 35,
                        color: Color(0xff274D76),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: myData.length,
                    itemBuilder: (context, index) {
                      bool isParticipantEvent =
                          myData[index]['isParticipantEvent'] ?? false;
                      return GestureDetector(
                          onTap: () => _showEventDetails(index),
                          child: Card(
                            color: Color(0xffe9edf1),
                            margin: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 5.0),
                                  child: Text(
                                    myData[index]['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                // Padding(
                                //   padding: EdgeInsets.fromLTRB(15.0, 0, 15.0, 5.0),
                                //   child: Text(
                                //     translate_title,
                                //     style: const TextStyle(
                                //       fontSize: 20,
                                //       color: Colors.black,
                                //       fontWeight: FontWeight.bold,
                                //     ),
                                //   ),
                                // ),
                                Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 5.0),
                                  child: Text(
                                    myData[index]['description'],
                                    style: TextStyle(
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(15.0, 0, 15.0, 5.0),
                                  child: Text(
                                    translate_description,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Data e Horário: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .spaceEvenly, // Alinha o texto ao centro
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text: 'Confirmações: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text:
                                              '${myData[index]['datas']} ${myData[index]['horario']}',
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .spaceEvenly, // Alinha o texto ao centro
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                text: 'N/A',
                                                style: const TextStyle(
                                                  color: Color(0xff274D76),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      Wrap(
                                        spacing:
                                            -8, // Valor negativo para reduzir o espaço entre os avatares
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Color(0xffe9edf1),
                                                  width: 2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor:
                                                  Color(0xff274D76),
                                              radius: 20,
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Color(0xffe9edf1),
                                                  width: 2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor:
                                                  Color(0xff274D76),
                                              radius: 20,
                                            ),
                                          ),
                                          // Adicione quantos avatares desejar, seguindo a mesma estrutura acima
                                        ],
                                      ),
                                      Expanded(child: Container()),
                                      if (!isParticipantEvent &&
                                          myData[index]['userId'] == user?.uid)
                                        ElevatedButton(
                                          onPressed: () =>
                                              showMyForm(myData[index]['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xffe9edf1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              side: BorderSide(
                                                  color: Color(0xff274D76)),
                                            ),
                                          ),
                                          child: Text(
                                            'Editar',
                                            style: TextStyle(
                                              color: Color(0xff274D76),
                                            ),
                                          ),
                                        ),
                                      SizedBox(width: 10),
                                      if (!isParticipantEvent &&
                                          myData[index]['userId'] == user?.uid)
                                        ElevatedButton(
                                          onPressed: () =>
                                              deleteItem(myData[index]['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xffe9edf1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              side: BorderSide(
                                                  color: Color(0xff274D76)),
                                            ),
                                          ),
                                          child: Text(
                                            'Deletar',
                                            style: TextStyle(
                                              color: Color(0xff274D76),
                                            ), // Define a cor azul para o texto
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ));
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width *
            0.95, // Definindo 80% da largura da tela
        height: 50,
        child: ElevatedButton(
          onPressed: () => showMyForm(null),
          child: Text(
            'Criar novo evento',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Color(0xff274D76), // Cor de fundo do botão
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void showMyForm(int? id) async {
    if (id != null) {
      final existingData = myData.firstWhere((element) => element['id'] == id);
      _titleController.text = existingData['title'];
      _descriptionController.text = existingData['description'];
      _enderecoController.text = existingData['endereco'];
      _horarioController.text = existingData['horario'];
      _datasController.text = existingData['datas'];
      _participantesController.text = existingData['participantes'];
    } else {
      _titleController.text = '';
      _descriptionController.text = '';
      _enderecoController.text = '';
      _horarioController.text = '';
      _datasController.text = '';
      _participantesController.text = '';
    }
    showModalBottomSheet(
        context: context,
        elevation: 5,
        isDismissible: false,
        isScrollControlled: true,
        builder: (_) => Container(
              padding: EdgeInsets.only(
                top: 15,
                right: 15,
                left: 15,
                bottom: MediaQuery.of(context).viewInsets.bottom + 120,
              ),
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _titleController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Titulo do Evento',
                    ),
                    onChanged: (text) async {
                      const _apiKey = 'AIzaSyCw2L2ZIhmqQ1kdn6hKrgUkdNys94YOnX8';
                      const to = 'en';
                      final url = Uri.parse(
                          'https://translation.googleapis.com/language/translate/v2?target=$to&key=$_apiKey&q=$text');
                      final response = await http.post(url);

                      if (response.statusCode == 200) {
                        final body = json.decode(response.body);
                        final translations =
                            body['data']['translations'] as List;
                        HtmlUnescape()
                            .convert(translations.first['translatedText']);
                      }

                      final translation =
                          await text.translate(from: 'auto', to: 'en');

                      setState(() {
                        translate_title = translation.text;
                      });
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Descricao',
                    ),
                    onChanged: (text) async {
                      const _apiKey = 'AIzaSyCw2L2ZIhmqQ1kdn6hKrgUkdNys94YOnX8';
                      const to = 'en';
                      final url = Uri.parse(
                          'https://translation.googleapis.com/language/translate/v2?target=$to&key=$_apiKey&q=$text');
                      final response = await http.post(url);

                      if (response.statusCode == 200) {
                        final body = json.decode(response.body);
                        final translations =
                            body['data']['translations'] as List;
                        HtmlUnescape()
                            .convert(translations.first['translatedText']);
                      }

                      final translation =
                          await text.translate(from: 'auto', to: 'en');

                      setState(() {
                        translate_description = translation.text;
                      });
                    },
                  ),
                  TextFormField(
                    controller: _enderecoController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Endereco',
                    ),
                  ),
                  TextFormField(
                    controller: _horarioController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Horario',
                    ),
                  ),
                  TextFormField(
                    controller: _datasController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Data',
                    ),
                  ),
                  TextFormField(
                    controller: _participantesController,
                    validator: validateMyTextField,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Participantes',
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xff274D76),
                            shadowColor: Color(0xff274D76),
                            surfaceTintColor: Color(0xff274D76),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancelar')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xff274D76),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              if (id != null) {
                                await updateItem(id);
                              } else {
                                await addItem();
                              }
                              Navigator.pop(context);
                            }
                            setState(() {
                              _titleController.text = '';
                              _descriptionController.text = '';
                              _enderecoController.text = '';
                              _horarioController.text = '';
                              _datasController.text = '';
                              _participantesController.text = '';
                            });
                          },
                          child: Text(id == null
                              ? 'Criar evento'
                              : "Atualizar evento")),
                    ],
                  )
                ]),
              ),
            ));
  }
}
