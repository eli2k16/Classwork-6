import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TaskApp());
}

class TaskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FirebaseAuth.instance.currentUser == null ? LoginScreen() : TaskListScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => TaskListScreen()));
    } catch (e) {
      print(e); // Handle sign-in error
    }
  }

  Future<void> signUp() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => TaskListScreen()));
    } catch (e) {
      print(e); // Handle sign-up error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(onPressed: signIn, child: Text('Login')),
            TextButton(onPressed: signUp, child: Text('Sign Up')),
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();

  void addTask(String name) {
    if (name.isEmpty) return;
    _firestore.collection('tasks').add({
      'name': name,
      'isComplete': false,
      'userId': _auth.currentUser?.uid,
      'subTasks': [] // Add additional task details here
    });
    _taskController.clear();
  }

  void toggleTaskCompletion(String taskId, bool isComplete) {
    _firestore.collection('tasks').doc(taskId).update({
      'isComplete': isComplete,
    });
  }

  void deleteTask(String taskId) {
    _firestore.collection('tasks').doc(taskId).delete();
  }

  Future<void> logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: 'Enter task name'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => addTask(_taskController.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('tasks')
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data?.docs ?? [];  // If snapshot.data is null, use an empty list.
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    String taskId = task.id;
                    String taskName = task['name'];
                    bool isComplete = task['isComplete'];

                    return ListTile(
                      title: Text(
                        taskName,
                        style: TextStyle(
                          decoration: isComplete
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      leading: Checkbox(
                        value: isComplete,
                        onChanged: (value) {
                          toggleTaskCompletion(taskId, value!);
                        },
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteTask(taskId),
                      ),
                      onTap: () {
                        // Handle task tap, show nested sub-tasks if available
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubTaskScreen(taskId: taskId),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SubTaskScreen extends StatefulWidget {
  final String taskId;

  SubTaskScreen({required this.taskId});

  @override
  _SubTaskScreenState createState() => _SubTaskScreenState();
}

class _SubTaskScreenState extends State<SubTaskScreen> {
  final _subTaskController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  void addSubTask(String timeFrame, String taskDetails) {
    if (timeFrame.isEmpty || taskDetails.isEmpty) return;

    _firestore.collection('tasks').doc(widget.taskId).collection('subTasks').add({
      'timeFrame': timeFrame,
      'details': taskDetails,
    });
    _subTaskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sub-Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskController,
                    decoration: InputDecoration(labelText: 'Enter sub-task details'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    addSubTask('To be done', _subTaskController.text);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('tasks')
                  .doc(widget.taskId)
                  .collection('subTasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final subTasks = snapshot.data?.docs ?? [];
                return ListView.builder(
                  itemCount: subTasks.length,
                  itemBuilder: (context, index) {
                    var subTask = subTasks[index];
                    String timeFrame = subTask['timeFrame'];
                    String taskDetails = subTask['details'];

                    return ListTile(
                      title: Text('$timeFrame: $taskDetails'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}