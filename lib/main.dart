import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';
import 'package:keyboard_event/keyboard_event.dart' as kb_event;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

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
  // Keyboard event handling
  late kb_event.KeyboardEvent keyboardEvent;
  bool listenIsOn = false;
  Timer? debounceTimer;
  bool isObsConnected = false;
  bool isNumLockOn = false;

  AudioPlayer audioPlayer = AudioPlayer();
  String? currentAudioPath;
  bool stopAudioWhenPressedAgain = false;
  bool isPlaying = false;

  // OBS related
  ObsWebSocket? obsWebSocket;
  List<String> obsSources = [];
  List<String> obsScenes = [];

  // Settings
  bool isDarkMode = true;
  Color borderColor = Colors.white;
  bool isCompactMode = true;
  double windowWidth = 500; // Default window width
  double windowHeight = 750; // Default window height
  
  String obsAddress = '';
  String obsPassword = '';

  // Key bindings
  Map<int, Map<String, String>> keyBindings = {};

  // Window titles
  static final List<String> windowTitles = [];

  late TextEditingController _obsAddressController;
  late TextEditingController _obsPasswordController;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    keyboardEvent = kb_event.KeyboardEvent();
    loadSettings();
    loadKeyBindings();
    _initializeWindow();

    // Initialize the controllers
    final parts = obsAddress.split(':');
    _obsAddressController = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
    _obsPasswordController = TextEditingController(text: obsPassword);
    _checkNumLockStatus();
  }

  void _checkNumLockStatus() {
    // Check Num Lock status every second
    Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        isNumLockOn = GetKeyState(VK_NUMLOCK) & 1 == 1;
      });
    });
  }

  Widget _buildGlowingTitle() {
    Color glowColor = Colors.transparent;
    if (listenIsOn && isNumLockOn) {
      glowColor = Colors.green;
    } else if (listenIsOn) {
      glowColor = Colors.yellow;
    }

    return Container(
      child: Text(
        'NumberDeck',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            for (double i = 1; i < 5; i++)
              Shadow(
                color: glowColor.withOpacity(0.3),
                blurRadius: 3 * i,
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _initializeWindow() async {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: ui.Size(windowWidth, windowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  void _updateWindowSize() {
    windowManager.setSize(ui.Size(windowWidth, windowHeight));
  }

  // Initialize platform state
  Future<void> initPlatformState() async {
    try {
      await kb_event.KeyboardEvent.init();
    } on PlatformException {
      print('Failed to initialize keyboard event package.');
    }
  }

  // Load settings
  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      borderColor = Color(prefs.getInt('border_color') ?? Colors.white.value);
      isCompactMode = prefs.getBool('is_compact_mode') ?? true;
      obsAddress = prefs.getString('obs_address') ?? '';
      obsPassword = prefs.getString('obs_password') ?? '';

      // Update the controllers
      _obsAddressController.text = obsAddress;
      _obsPasswordController.text = obsPassword;
    });
    await connectToObs();
  }

  // Save settings
  void saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
    await prefs.setInt('border_color', borderColor.value);
    await prefs.setBool('is_compact_mode', isCompactMode);
    await prefs.setString('obs_address', obsAddress);
    await prefs.setString('obs_password', obsPassword);

    // Update the controllers
    _obsAddressController.text = obsAddress;
    _obsPasswordController.text = obsPassword;
  }

  // Reset all settings and key bindings
  void resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      isDarkMode = true;
      borderColor = Colors.white;
      isCompactMode = true;
      keyBindings.clear();
    });
  }

  // Connect to OBS
  Future<void> connectToObs() async {
    if (obsAddress.isEmpty || obsPassword.isEmpty) {
      showToast('OBS address or password not set');
      return;
    }

    try {
      // The obsAddress should already be in the format "ip:port"
      obsWebSocket = await ObsWebSocket.connect(
        obsAddress,
        password: obsPassword,
      );

      if (obsWebSocket != null) {
        await fetchObsSources();
        await fetchObsScenes();
        setState(() {
          isObsConnected = true;
        });
        showToast('Connected to OBS');
      }
    } catch (e) {
      print('Error connecting to OBS: $e');
      showToast('Cannot connect to OBS');
      setState(() {
        isObsConnected = false;
      });
    }
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Fetch OBS sources
  Future<void> fetchObsSources() async {
    if (obsWebSocket == null) return;

    try {
      final response = await obsWebSocket!.send('GetInputList');
      if (response != null) {
        final responseMap = response.responseData as Map<String, dynamic>;
        setState(() {
          obsSources = List<String>.from(responseMap['inputs'].map((input) => input['inputName']));
        });
      }
    } catch (e) {
      print('Error fetching OBS sources: $e');
    }
  }

  // Fetch OBS scenes
  Future<void> fetchObsScenes() async {
    if (obsWebSocket == null) return;

    try {
      final response = await obsWebSocket!.send('GetSceneList');
      if (response != null) {
        final responseMap = response.responseData as Map<String, dynamic>;
        setState(() {
          obsScenes = List<String>.from(responseMap['scenes'].map((scene) => scene['sceneName']));
        });
      }
    } catch (e) {
      print('Error fetching OBS scenes: $e');
    }
  }
  
  Future<void> pickAndPlayAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      String selectedFilePath = result.files.first.path!;

      // If checkbox is enabled and same audio is playing, stop it
      if (stopAudioWhenPressedAgain && isPlaying && selectedFilePath == currentAudioPath) {
        await audioPlayer.stop();
        setState(() {
          isPlaying = false;
        });
        return;
      }

      // Play the selected file
      await audioPlayer.play(DeviceFileSource(selectedFilePath));
      setState(() {
        currentAudioPath = selectedFilePath;
        isPlaying = true;
      });

      // Listen for when the audio finishes playing
      audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          isPlaying = false;
        });
      });
    }
  }

  // Load key bindings
  void loadKeyBindings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var keyCode in [VK_NUMPAD0, VK_NUMPAD1, VK_NUMPAD2, VK_NUMPAD3, VK_NUMPAD4, VK_NUMPAD5, VK_NUMPAD6, VK_NUMPAD7, VK_NUMPAD8, VK_NUMPAD9]) {
      final binding = prefs.getString('key_binding_$keyCode');
      if (binding != null) {
        final parts = binding.split('|');
        if (parts.length == 3) {
          keyBindings[keyCode] = {'category': parts[0], 'action': parts[1], 'parameter': parts[2]};
        }
      }
    }
  }

  // Save key binding
  void saveKeyBinding(int keyCode, String category, String action, String parameter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key_binding_$keyCode', '$category|$action|$parameter');
    setState(() {
      keyBindings[keyCode] = {'category': category, 'action': action, 'parameter': parameter};
    });
    print("Saved key binding: $keyCode -> $category|$action|$parameter");
  }

  // Key event handler
  void onKeyEvent(kb_event.KeyEvent keyEvent) async {
    int vkCode = keyEvent.vkCode;

    if (keyBindings.containsKey(vkCode)) {
      final binding = keyBindings[vkCode]!;

      if (binding['category'] == 'Audio') {
        String filePath = binding['parameter']!;

        if (stopAudioWhenPressedAgain && isPlaying) {
          await audioPlayer.stop();
          setState(() {
            isPlaying = false;
            currentAudioPath = null;
          });
          return; // Exit early, so no new audio starts
        }

        await audioPlayer.play(DeviceFileSource(filePath));
        setState(() {
          currentAudioPath = filePath;
          isPlaying = true;
        });

        audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            isPlaying = false;
            currentAudioPath = null;
          });
        });
      }
    }
  }

  // Update executeShortcut method
  void executeShortcut(String shortcut) {
    print("Executing shortcut: $shortcut");
    List<String> keys = shortcut.split(' + ');
    List<int> vkCodes = [];
    bool hasWinKey = keys.remove('Win');
    
    vkCodes.addAll(keys.map((key) => getVirtualKeyCode(key)).where((vk) => vk != 0));
    
    if (hasWinKey) {
      vkCodes.insert(0, VK_LWIN);
    }
    
    print("Virtual key codes: $vkCodes");

    final pInputs = calloc<INPUT>(vkCodes.length * 2);
    
    for (var i = 0; i < vkCodes.length; i++) {
      // Key press
      pInputs[i].type = INPUT_KEYBOARD;
      pInputs[i].ki.wVk = vkCodes[i];
      pInputs[i].ki.wScan = MapVirtualKey(vkCodes[i], 0);
      pInputs[i].ki.dwFlags = 0;
      pInputs[i].ki.time = 0;
      pInputs[i].ki.dwExtraInfo = 0;

      // Key release
      pInputs[i + vkCodes.length].type = INPUT_KEYBOARD;
      pInputs[i + vkCodes.length].ki.wVk = vkCodes[i];
      pInputs[i + vkCodes.length].ki.wScan = MapVirtualKey(vkCodes[i], 0);
      pInputs[i + vkCodes.length].ki.dwFlags = KEYEVENTF_KEYUP;
      pInputs[i + vkCodes.length].ki.time = 0;
      pInputs[i + vkCodes.length].ki.dwExtraInfo = 0;
    }

    final result = SendInput(vkCodes.length * 2, pInputs, sizeOf<INPUT>());
    print("SendInput result: $result");

    calloc.free(pInputs);
  }
  
  bool isModifierKey(int vkCode) {
    return vkCode == VIRTUAL_KEY.VK_CONTROL || vkCode == VIRTUAL_KEY.VK_SHIFT || vkCode == VIRTUAL_KEY.VK_MENU || vkCode == VIRTUAL_KEY.VK_LWIN;
  }

  int getVirtualKeyCode(String key) {
    switch (key.toLowerCase()) {
      case 'control left':
      case 'ctrl':
        return VIRTUAL_KEY.VK_LCONTROL;
      case 'control right':
        return VIRTUAL_KEY.VK_RCONTROL;
      case 'shift left':
      case 'shift':
        return VIRTUAL_KEY.VK_LSHIFT;
      case 'shift right':
        return VIRTUAL_KEY.VK_RSHIFT;
      case 'alt left':
      case 'alt':
        return VIRTUAL_KEY.VK_LMENU;
      case 'alt right':
        return VIRTUAL_KEY.VK_RMENU;
      case 'win':
      case 'windows':
        return VIRTUAL_KEY.VK_LWIN;
      default:
        if (key.length == 1) {
          final result = key.toUpperCase().codeUnitAt(0);
          return result & 0xFF;  // Return the low byte (virtual key code)
        }
    }
    print("Unknown key: $key");
    return 0;
  }

  // Toggle window or perform OBS action
  void toggleWindow(int vkCode) {
    if (!keyBindings.containsKey(vkCode)) return;

    final binding = keyBindings[vkCode]!;
    if (binding['category'] == 'Windows') {
      final windowTitle = binding['action']!;
      final hWnd = FindWindow(nullptr, windowTitle.toNativeUtf16());

      if (hWnd == 0) {
        print("Window with title '$windowTitle' not found.");
        return;
      }

      final isMinimized = IsIconic(hWnd) != 0;

      if (isMinimized) {
        ShowWindow(hWnd, SW_RESTORE);
      } else {
        ShowWindow(hWnd, SW_MINIMIZE);
      }
    } else if (binding['category'] == 'OBS') {
      performObsAction(binding['action']!, binding['parameter']);
    }
  }

  // Perform OBS action
  void performObsAction(String action, String? parameter) async {
    if (obsWebSocket == null) {
      print('OBS WebSocket is not connected');
      return;
    }

    try {
      switch (action) {
        case 'Switch Scene':
          await obsWebSocket!.send('SetCurrentProgramScene', {'sceneName': parameter});
          break;
        case 'Mute Source':
          await obsWebSocket!.send('SetInputMute', {'inputName': parameter, 'inputMuted': true});
          break;
        case 'Unmute Source':
          await obsWebSocket!.send('SetInputMute', {'inputName': parameter, 'inputMuted': false});
          break;
        case 'Toggle Source Mute':
          await obsWebSocket!.send('ToggleInputMute', {'inputName': parameter});
          break;
        case 'Start Streaming':
          await obsWebSocket!.send('StartStream');
          break;
        case 'Stop Streaming':
          await obsWebSocket!.send('StopStream');
          break;
        case 'Start Recording':
          await obsWebSocket!.send('StartRecord');
          break;
        case 'Pause Recording':
          await obsWebSocket!.send('PauseRecord');
          break;
        case 'Resume Recording':
          await obsWebSocket!.send('ResumeRecord');
          break;
        case 'Stop Recording':
          await obsWebSocket!.send('StopRecord');
          break;
        case 'Toggle Source Visibility':
          final sceneItemId = await getSceneItemId(parameter!);
          await obsWebSocket!.send('SetSceneItemEnabled', {
            'sceneName': await getCurrentScene(),
            'sceneItemId': sceneItemId,
            'sceneItemEnabled': !(await isSceneItemEnabled(parameter))
          });
          break;
      }
      print('OBS action performed: $action');
    } catch (e) {
      print('Error performing OBS action: $e');
    }
  }

  // Get current OBS scene
  Future<String> getCurrentScene() async {
    final response = await obsWebSocket!.send('GetCurrentProgramScene');
    return (response?.responseData as Map<String, dynamic>)['currentProgramSceneName'] ?? '';
  }

  // Get scene item ID
  Future<int> getSceneItemId(String sourceName) async {
    final currentScene = await getCurrentScene();
    final response = await obsWebSocket!.send('GetSceneItemList', {'sceneName': currentScene});
    if (response != null) {
      final sceneItems = (response.responseData as Map<String, dynamic>)['sceneItems'] as List;
      final sceneItem = sceneItems.firstWhere((item) => item['sourceName'] == sourceName, orElse: () => null);
      return sceneItem?['sceneItemId'] ?? -1;
    }
    return -1;
  }

  // Check if scene item is enabled
  Future<bool> isSceneItemEnabled(String sourceName) async {
    final currentScene = await getCurrentScene();
    final sceneItemId = await getSceneItemId(sourceName);
    if (sceneItemId == -1) return false;
    final response = await obsWebSocket!.send('GetSceneItemEnabled', {
      'sceneName': currentScene,
      'sceneItemId': sceneItemId,
    });
    return (response?.responseData as Map<String, dynamic>)['sceneItemEnabled'] ?? false;
  }

  // Get active windows
  List<String> getActiveWindows() {
    windowTitles.clear();

    final enumWindowsProc = Pointer.fromFunction<NativeEnumWindowsProc>(
      _enumWindowsCallback,
      0,
    );

    EnumWindows(enumWindowsProc, 0);

    return windowTitles;
  }

  // Callback for enumerating windows
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

  // Start listening for key events
  void startListening() {
    setState(() {
      listenIsOn = true;
    });
    keyboardEvent.startListening(onKeyEvent);
  }

  // Stop listening for key event
  void stopListening() {
    setState(() {
      listenIsOn = false;
    });
    keyboardEvent.cancelListening();
  }

  // Show binding dialog
  Future<void> showBindingDialog(int keyCode) async {
    String? selectedCategory = keyBindings[keyCode]?['category'];
    String? selectedAction = keyBindings[keyCode]?['action'];
    String? selectedParameter = keyBindings[keyCode]?['parameter'];
    bool toggleMuteAction = false;
    List<String> actions = [];
    String capturedShortcut = '';
    TextEditingController shortcutController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Bind Action to Key ${keyCode - VK_NUMPAD0}'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedCategory == 'OBS' && !isObsConnected)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'OBS is not connected',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      items: ['OBS', 'Windows', 'Shortcuts', 'Audio'].map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          selectedCategory = value;
                          selectedAction = null;
                          selectedParameter = null;
                          actions = value == 'OBS' ? obsActions : (value == 'Windows' ? getActiveWindows() : []);
                          shortcutController.clear();
                        });
                      },
                    ),
                    if (selectedCategory == 'Shortcuts')
                      ListTile(
                        title: Text('Shortcut: ${capturedShortcut.isEmpty ? 'Not set' : capturedShortcut}'),
                        trailing: ElevatedButton(
                          child: Text('Capture'),
                          onPressed: () async {
                            String shortcut = await captureShortcut(context);
                            setState(() {
                              capturedShortcut = shortcut;
                            });
                          },
                        ),
                      )
                    else if (selectedCategory != null && selectedCategory != 'Audio')
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedAction,
                        items: actions.map((String action) {
                          return DropdownMenuItem<String>(
                            value: action,
                            child: Text(action),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedAction = value;
                            selectedParameter = null;
                            toggleMuteAction = false;
                          });
                        },
                      ),
                    if (selectedCategory == 'Audio')
                      ListTile(
                        title: Text('Pick Audio File'),
                        trailing: ElevatedButton(
                          child: Text('Pick'),
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.audio,
                            );

                            if (result != null) {
                              PlatformFile file = result.files.first;
                              setState(() {
                                selectedParameter = file.path;
                              });
                            }
                          },
                        ),
                      ),
                    if (selectedCategory == 'OBS' && selectedAction != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButton<String>(
                            isExpanded: true,
                            value: selectedParameter,
                            items: (selectedAction!.contains('Scene') ? obsScenes : obsSources).map((String param) {
                              return DropdownMenuItem<String>(
                                value: param,
                                child: Text(param),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                selectedParameter = value;
                              });
                            },
                          ),
                          if (selectedAction == 'Mute Source' || selectedAction == 'Unmute Source')
                            CheckboxListTile(
                              title: Text('Work as both Mute/Unmute'),
                              value: toggleMuteAction,
                              onChanged: (bool? value) {
                                setState(() {
                                  toggleMuteAction = value ?? false;
                                });
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (selectedCategory == 'Shortcuts' && capturedShortcut.isNotEmpty) {
                      saveKeyBinding(keyCode, 'Shortcuts', 'Execute Shortcut', capturedShortcut);
                    } else if (selectedCategory != null && selectedAction != null) {
                      String finalAction = selectedAction!;
                      if (toggleMuteAction && (finalAction == 'Mute Source' || finalAction == 'Unmute Source')) {
                        finalAction = 'Toggle Source Mute';
                      }
                      saveKeyBinding(keyCode, selectedCategory!, finalAction, selectedParameter ?? '');
                    }
                    if (selectedCategory == 'Audio' && selectedParameter != null) {
                      saveKeyBinding(keyCode, 'Audio', 'Play Audio', selectedParameter!);
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> captureShortcut(BuildContext context) async {
    Set<LogicalKeyboardKey> pressedKeys = {};
    String shortcut = '';
    bool isWindowsKeyPressed = false;

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.metaLeft || 
                  event.logicalKey == LogicalKeyboardKey.metaRight) {
                isWindowsKeyPressed = true;
              }
              if (!pressedKeys.contains(event.logicalKey)) {
                pressedKeys.add(event.logicalKey);
                shortcut = _buildShortcutString(pressedKeys, isWindowsKeyPressed);
                (context as Element).markNeedsBuild();
              }
            } else if (event is RawKeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.metaLeft || 
                  event.logicalKey == LogicalKeyboardKey.metaRight) {
                isWindowsKeyPressed = false;
              }
              pressedKeys.remove(event.logicalKey);
              if (pressedKeys.isEmpty || pressedKeys.length == 3 || 
                  (isWindowsKeyPressed && pressedKeys.length == 2)) {
                Navigator.of(context).pop(shortcut);
              }
            }
          },
          child: AlertDialog(
            title: Text('Press up to 3 keys (including Win key)'),
            content: Text(shortcut.isEmpty ? 'Waiting for input...' : shortcut),
          ),
        );
      },
    ) ?? '';
  }

  String _buildShortcutString(Set<LogicalKeyboardKey> keys, bool isWindowsKeyPressed) {
    List<String> keyLabels = [];
    if (isWindowsKeyPressed) keyLabels.add('Win');
    for (var key in keys) {
      keyLabels.add(_getKeyLabel(key));
    }
    return keyLabels.join(' + ');
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.control) return 'Ctrl';
    if (key == LogicalKeyboardKey.alt) return 'Alt';
    if (key == LogicalKeyboardKey.shift) return 'Shift';
    if (key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight) return 'Win';
    return key.keyLabel;
  }

  // List of OBS actions
  List<String> get obsActions => [
    'Switch Scene',
    'Mute Source',
    'Unmute Source',
    'Toggle Source Mute',
    'Start Streaming',
    'Stop Streaming',
    'Start Recording',
    'Pause Recording',
    'Resume Recording',
    'Stop Recording',
    'Toggle Source Visibility',
  ];

  // Build a key widget
  Widget buildKey(String label, int keyCode, double x, double y, double width, double height) {
    return Positioned(
      left: x * width,
      top: y * height,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => showBindingDialog(keyCode),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: Icon(Icons.settings, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () => showBindingDialog(keyCode),
                ),
              ),
              if (keyBindings.containsKey(keyCode))
                Positioned(
                  bottom: 5,
                  left: 5,
                  child: Text(
                    '${keyBindings[keyCode]!['category']}: ${keyBindings[keyCode]!['action']}',
                    style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Show settings dialog
  void showSettingsDialog() {
    TextEditingController tempIpController = TextEditingController();
    TextEditingController tempPortController = TextEditingController();
    TextEditingController tempPasswordController = TextEditingController(text: obsPassword);
    
    // Split the existing obsAddress into IP and port
    if (obsAddress.isNotEmpty) {
      final parts = obsAddress.split(':');
      tempIpController.text = parts[0];
      if (parts.length > 1) {
        tempPortController.text = parts[1];
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      color: Colors.green.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            value: isDarkMode,
                            onChanged: (value) {
                              setState(() {
                                isDarkMode = value;
                              });
                              this.setState(() {}); // Update the main UI
                            },
                          ),
                          ListTile(
                            title: const Text('Border Color'),
                            trailing: GestureDetector(
                              onTap: () async {
                                final Color? color = await showColorPicker(context, borderColor);
                                if (color != null) {
                                  setState(() {
                                    borderColor = color;
                                  });
                                  this.setState(() {}); // Update the main UI
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                color: borderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      color: Colors.blue.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OBS Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                flex: 7,
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'OBS IP'),
                                  controller: tempIpController,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Port'),
                                  controller: tempPortController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          TextField(
                            decoration: const InputDecoration(labelText: 'OBS Password'),
                            controller: tempPasswordController,
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.red.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          const Divider(color: Colors.red),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              child: const Text('Reset All Settings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Reset'),
                                      content: const Text('Are you sure you want to reset all settings? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Reset'),
                                          onPressed: () {
                                            resetAll();
                                            Navigator.of(context).pop();
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Apply'),
                  onPressed: () async {
                    // Combine IP and port for obsAddress
                    obsAddress = '${tempIpController.text}:${tempPortController.text}';
                    obsPassword = tempPasswordController.text;

                    // Update the main controllers
                    _obsAddressController.text = obsAddress;
                    _obsPasswordController.text = obsPassword;

                    saveSettings();
                    this.setState(() {}); // Update the main UI
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show color picker
  Future<Color?> showColorPicker(BuildContext context, Color initialColor) async {
    return await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        Color selectedColor = initialColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: initialColor,
              onColorChanged: (Color color) {
                selectedColor = color;
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Select'),
              onPressed: () {
                Navigator.of(context).pop(selectedColor);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final keyWidth = screenSize.width / 4;
    final keyHeight = screenSize.height / 5.43;


    return MaterialApp(
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: _buildGlowingTitle(),
          actions: [
            Tooltip(
              message: listenIsOn ? 'Stop Listening' : 'Start Listening',
              child: IconButton(
                icon: Icon(listenIsOn ? Icons.power_off : Icons.power),
                onPressed: listenIsOn ? stopListening : startListening,
              ),
            ),
            if (obsAddress.isNotEmpty && obsPassword.isNotEmpty)
              Tooltip(
                message: isObsConnected ? 'Connected to OBS' : 'Connect to OBS',
                child: IconButton(
                  icon: Icon(Icons.videocam, color: isObsConnected ? Colors.green : Colors.red),
                  onPressed: connectToObs,
                ),
              ),
            Tooltip(
              message: 'Settings',
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: showSettingsDialog,
              ),
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
                buildKey('/', VK_DIVIDE, 1, 0, keyWidth, keyHeight),
                buildKey('*', VK_MULTIPLY, 2, 0, keyWidth, keyHeight),
                buildKey('-', VK_SUBTRACT, 3, 0, keyWidth, keyHeight),
                buildKey('7', VK_NUMPAD7, 0, 1, keyWidth, keyHeight),
                buildKey('8', VK_NUMPAD8, 1, 1, keyWidth, keyHeight),
                buildKey('9', VK_NUMPAD9, 2, 1, keyWidth, keyHeight),
                buildKey('+', VK_ADD, 3, 0.5, keyWidth, keyHeight * 2),
                buildKey('4', VK_NUMPAD4, 0, 2, keyWidth, keyHeight),
                buildKey('5', VK_NUMPAD5, 1, 2, keyWidth, keyHeight),
                buildKey('6', VK_NUMPAD6, 2, 2, keyWidth, keyHeight),
                buildKey('1', VK_NUMPAD1, 0, 3, keyWidth, keyHeight),
                buildKey('2', VK_NUMPAD2, 1, 3, keyWidth, keyHeight),
                buildKey('3', VK_NUMPAD3, 2, 3, keyWidth, keyHeight),
                buildKey('Enter', VK_RETURN, 3, 1.5, keyWidth, keyHeight * 2),
                buildKey('0', VK_NUMPAD0, 0, 4, keyWidth * 2, keyHeight),
                buildKey('.', VK_DECIMAL, 2, 4, keyWidth, keyHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}