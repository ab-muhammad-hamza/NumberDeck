import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';
import 'package:keyboard_event/keyboard_event.dart' as kb_event;

typedef NativeEnumWindowsProc = Uint32 Function(IntPtr, IntPtr);
typedef DartEnumWindowsProc = int Function(int, int);

void main() {
  runApp(const MyAppWrapper());
}

class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late kb_event.KeyboardEvent keyboardEvent;
  bool listenIsOn = false;
  Timer? debounceTimer;
  Map<int, String> keyWindowMap = {};
  String selectedWindow = "Select Window";
  static final List<String> windowTitles = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    keyboardEvent = kb_event.KeyboardEvent();
  }

  Future<void> initPlatformState() async {
    try {
      await kb_event.KeyboardEvent.init();
    } on PlatformException {
      print('Failed to initialize keyboard event package.');
    }
  }

  void onKeyEvent(kb_event.KeyEvent keyEvent) {
    if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 300), () {
      toggleWindow(keyEvent.vkCode);
    });
  }

  void toggleWindow(int vkCode) {
    if (!keyWindowMap.containsKey(vkCode)) return;

    final hWnd = FindWindow(nullptr, keyWindowMap[vkCode]!.toNativeUtf16());

    if (hWnd == 0) {
      print("Window with title '${keyWindowMap[vkCode]}' not found.");
      return;
    }

    final isMinimized = IsIconic(hWnd) != 0;

    if (isMinimized) {
      ShowWindow(hWnd, SW_RESTORE);
    } else {
      ShowWindow(hWnd, SW_MINIMIZE);
    }
  }

  void startListening() {
    setState(() {
      listenIsOn = true;
    });
    keyboardEvent.startListening(onKeyEvent);
  }

  void stopListening() {
    setState(() {
      listenIsOn = false;
    });
    keyboardEvent.cancelListening();
  }

  List<String> getActiveWindows() {
    windowTitles.clear(); // Ensure this clears the list

    final enumWindowsProc = Pointer.fromFunction<NativeEnumWindowsProc>(
      _enumWindowsCallback,
      0, // Exception return value
    );

    EnumWindows(enumWindowsProc, 0);

    return windowTitles;
  }

  // Static callback function to collect window titles
  static int _enumWindowsCallback(int hWnd, int lParam) {
    final length = GetWindowTextLength(hWnd);
    if (length == 0) {
      return 1;
    }

    if (IsWindowVisible(hWnd) == 0 || GetWindow(hWnd, GW_OWNER) != 0) {
      return 1;
    }

    final buffer = wsalloc(length + 1);
    GetWindowText(hWnd, buffer, length + 1);
    final windowTitle = buffer.toDartString();
    free(buffer);

    if (windowTitle.isNotEmpty &&
        windowTitle != "Default IME" &&
        windowTitle != "MSCTFIME UI" &&
        windowTitle != "CiceroUIWndFrame" &&
        windowTitle != "IME") {
      windowTitles.add(windowTitle);
    }

    return 1;
  }

  Future<void> showWindowSelectionDialog(int numpadKey) async {
    List<String> windows = getActiveWindows();
    String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Window'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: windows.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(windows[index]),
                  onTap: () {
                    Navigator.pop(context, windows[index]);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        selectedWindow = selected;
        keyWindowMap[numpadKey] = selectedWindow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final keyWidth = screenSize.width / 4;
    final keyHeight = screenSize.height / 5.43;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NumberDeck'),
        actions: [
          IconButton(
            icon: Icon(listenIsOn ? Icons.power_off : Icons.power),
            onPressed: listenIsOn ? stopListening : startListening,
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: Stack(
            children: [
              buildKey('Num Lock', VK_NUMLOCK, 0, 0, keyWidth, keyHeight),
              buildKey('Divide', VK_DIVIDE, 1, 0, keyWidth, keyHeight),
              buildKey('Multiply', VK_MULTIPLY, 2, 0, keyWidth, keyHeight),
              buildKey('Minus', VK_SUBTRACT, 3, 0, keyWidth, keyHeight),
              buildKey('7', VK_NUMPAD7, 0, 1, keyWidth, keyHeight),
              buildKey('8', VK_NUMPAD8, 1, 1, keyWidth, keyHeight),
              buildKey('9', VK_NUMPAD9, 2, 1, keyWidth, keyHeight),
              buildKey('Plus', VK_ADD, 3, 0.5, keyWidth, keyHeight * 2), // span two rows
              buildKey('4', VK_NUMPAD4, 0, 2, keyWidth, keyHeight),
              buildKey('5', VK_NUMPAD5, 1, 2, keyWidth, keyHeight),
              buildKey('6', VK_NUMPAD6, 2, 2, keyWidth, keyHeight),
              buildKey('1', VK_NUMPAD1, 0, 3, keyWidth, keyHeight),
              buildKey('2', VK_NUMPAD2, 1, 3, keyWidth, keyHeight),
              buildKey('3', VK_NUMPAD3, 2, 3, keyWidth, keyHeight),
              buildKey('Enter', VK_RETURN, 3, 1.5, keyWidth, keyHeight * 2), // span two rows
              buildKey('0', VK_NUMPAD0, 0, 4, keyWidth * 2, keyHeight), // span two columns
              buildKey('Dot', VK_DECIMAL, 2, 4, keyWidth, keyHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildKey(String label, int keyCode, double x, double y, double width, double height) {
    return Positioned(
      left: x * width,
      top: y * height,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => showWindowSelectionDialog(keyCode),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            color: Colors.grey[800],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: Icon(Icons.settings, color: Colors.white),
                  onPressed: () => showWindowSelectionDialog(keyCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
