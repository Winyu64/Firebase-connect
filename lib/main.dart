import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // นำเข้า Firestore
import 'firebase_options.dart'; // นำเข้า firebase_options.dart ที่สร้างจาก FlutterFire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const TodoApp(),
    );
  }
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late TextEditingController _titleController;
  late TextEditingController _detailsController;
  bool _completed = false; // สถานะทำเสร็จหรือไม่

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _detailsController = TextEditingController();
  }

  // ฟังก์ชันเพิ่มข้อมูลลง Firestore
  void addTodoToFirestore(String title, String details, bool completed) {
    FirebaseFirestore.instance.collection('todos').add({
      'title': title,
      'details': details,
      'completed': completed,
    }).then((value) {
      print("Todo Added");
    }).catchError((error) {
      print("Failed to add todo: $error");
    });
  }

  // ฟังก์ชันแก้ไขข้อมูลใน Firestore
  void updateTodoInFirestore(String docId, String title, String details, bool completed) {
    FirebaseFirestore.instance.collection('todos').doc(docId).update({
      'title': title,
      'details': details,
      'completed': completed,
    }).then((value) {
      print("Todo Updated");
    }).catchError((error) {
      print("Failed to update todo: $error");
    });
  }

  // ฟังก์ชันลบข้อมูลจาก Firestore
  void deleteTodoFromFirestore(String docId) {
    FirebaseFirestore.instance.collection('todos').doc(docId).delete().then((value) {
      print("Todo Deleted");
    }).catchError((error) {
      print("Failed to delete todo: $error");
    });
  }

  // ฟังก์ชันเปิด Dialog เพื่อเพิ่มหรือแก้ไขข้อมูล
  void showTodoDialog(BuildContext context, {String? docId, String? title, String? details, bool? completed}) {
    _titleController.text = title ?? '';
    _detailsController.text = details ?? '';
    _completed = completed ?? false; // กำหนดค่าเริ่มต้นของสถานะ

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(docId == null ? "Add new task" : "Edit task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Task title",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Task details",
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Completed: "),
                  Checkbox(
                    value: _completed,
                    onChanged: (value) {
                      setState(() {
                        _completed = value!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (docId == null) {
                  // เพิ่มข้อมูลใหม่
                  addTodoToFirestore(_titleController.text, _detailsController.text, _completed);
                } else {
                  // แก้ไขข้อมูลเดิม
                  updateTodoInFirestore(docId, _titleController.text, _detailsController.text, _completed);
                }
                _titleController.clear();
                _detailsController.clear();
                Navigator.pop(context);
              },
              child: Text(docId == null ? "Save" : "Update"),
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
        title: const Text("Todo"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('todos').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final todos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              var todo = todos[index];
              final data = todo.data() as Map<String, dynamic>; // แปลงข้อมูลให้เป็น Map

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  elevation: 4,
                  child: ListTile(
                    title: Text(
                      data['title'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        // ตรวจสอบว่าฟิลด์ 'completed' มีอยู่หรือไม่ ถ้าไม่มีกำหนดเป็น false
                        decoration: (data.containsKey('completed') && data['completed'])
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(data['details']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            showTodoDialog(
                              context,
                              docId: todo.id,
                              title: data['title'],
                              details: data['details'],
                              // ตรวจสอบฟิลด์ 'completed' ก่อน ถ้าไม่มีให้กำหนดเป็น false
                              completed: data.containsKey('completed') ? data['completed'] : false,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            deleteTodoFromFirestore(todo.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showTodoDialog(context); // เปิด Dialog เพื่อเพิ่มข้อมูลใหม่
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}