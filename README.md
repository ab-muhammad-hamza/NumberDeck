<div align="center">

<img src="https://i.imgur.com/aLXOxKW.png" alt="NumberDeck Cover">

# NumberDeck

### Transform Your Numpad into a Productivity Powerhouse

[![Release](https://img.shields.io/github/v/release/ab-muhammad-hamza/numberdeck.svg)](https://github.com/ab-muhammad-hamza/NumberDeck/releases/)
[![License](https://img.shields.io/github/license/ab-muhammad-hamza/numberdeck.svg)](https://github.com/ab-muhammad-hamza/NumberDeck/blob/main/LICENSE)
[![Stars](https://img.shields.io/github/stars/ab-muhammad-hamza/numberdeck.svg)](https://github.com/ab-muhammad-hamza/NumberDeck/stargazers)
[![Issues](https://img.shields.io/github/issues/ab-muhammad-hamza/numberdeck.svg)](https://github.com/ab-muhammad-hamza/NumberDeck/issues)

[Download](https://github.com/ab-muhammad-hamza/NumberDeck/releases/download/BETA/NumberDeck.zip) | [Report Bug](https://github.com/ab-muhammad-hamza/NumberDeck/issues) | [Request Feature](https://github.com/ab-muhammad-hamza/NumberDeck/issues)

</div>

##  <img src="https://i.imgur.com/xJNGTjg.png" alt="LOOG" width="16px"> What is NumberDeck?

NumberDeck is an open-source project that replaces the physical Stream Deck with your Num Pad on your keyboard. NumberDeck was first designed to be helpful for streamers, but it can be used for any day-to-day work. In simple words, it turns your keyboard into a fully functioning Stream Deck!

<table>
  <tr>
    <th><a href="#server-invite">Server Invite</a></th>
    <td><a target="_blank" href="https://discord.gg/vAkRjnyPeT"><img src="https://dcbadge.limes.pink/api/server/vAkRjnyPeT" alt="" /></a></td>
  </tr>
</table>

## ✨ Features

- 🎮 **OBS Integration**: Control your streams with ease
- 🖥️ **Window Management**: Switch between applications effortlessly
- ⌨️ **Custom Shortcuts**: Create powerful macros for complex tasks
- 🌓 **Dark/Light Mode**: Work comfortably in any lighting condition
- 🎨 **Customizable UI**: Personalize your NumberDeck experience

## 🛠️ Installation

1. [Download](https://github.com/ab-muhammad-hamza/NumberDeck/releases/download/BETA/NumberDeck.zip) the latest release
2. Extract the ZIP file to your preferred location
3. Run `numberdeck.exe` to start the application

## 🔧 Usage

1. Click the gear icon on any numpad key to configure
2. Choose an action (OBS control, window management, or custom shortcut)
3. Click the power button in the app to start listening for keypresses
4. Use your numpad to execute your configured actions!


## 🖥️ Usage

Same section again? Yes this section will tell you more!

In the beginning, it was mainly designed for streamers. Now, it can be used by anyone with three major options.

### 🎮 For Streamers:

Streamers can use it to bind their NumPad keys to their OBS and can do the following:

<img src="https://i.imgur.com/5azfsGb.gif" width="100%" alt="" />

 - Switch Scene
 - Mute Source
 - Unmute Source
 - Toggle Source Mute
 - Start Streaming
 - Stop Streaming
 - Start Recording
 - Pause Recording
 - Resume Recording
 - Stop Recording
 - Toggle Source Visibility

Every action like switching scenes, will have its own additional option to get the element/source/scene from the OBS and a particular element/source/scene can be selected!

PS: You can bind the same NumKey to mute and unmute any source at the same time.

#### How to Connect?

- [Download](https://obsproject.com/) and Install OBS if you haven't already installed
- Open OBS Studio and locate **Tools > WebSocket Server Settings** which can be found on the ribbon menu
- Check the box on "Enable WebSocket Server"
- Click on "Show Connect info"
- Copy the Server IP and Server Password
- Now open NumberDeck, and click on the gear icon which is at the top.
- Paste the details in the OBS section
  - OBS Address = Server IP
    - In the IP address add a colon and copy the port from OBS and paste it. (if the IP is x.x.x.x, and the port is 123, then the address needed to be x.x.x.x:123) [The next update will have a separate field for this :)
  - OBS Password = Server Password
- Click save after entering them
- Now you'll see a camera icon at the top of the app in red color. Click on it to connect to OBS

There we go, it's done. Seeing these steps might seem like a big process. But trust me, it's really simple. I'll make a simple video on how to do that soon :)

### 🧑‍💻 For Developers

<img src="https://i.imgur.com/WegbXR5.gif" width="100%" alt="" />

Developers can use NumberDeck in endless possible ways. My Fav usage is ctrl + shift + n to create a new folder any time, and ofc ctrl + c and ctrl + v 😁. The Shortcut section makes it easier for developers to bind any shortcuts to the keyboard's NumPad. Don't get me wrong, OBS and windows options also will be useful for developers!!.

#### How to add shortcuts?

- Open up NumberDeck
- Click on your number of choice which you want to bind the shortcut to
- Choose Shortcuts from the options.
- Click on capture
- Press the shortcut keys
- Save and use!!

### 🎨 For Creatives

Let me break it down. Every feature can be used by anyone. I am just giving the title so it will look a bit different. This is a window option, which is the basic feature of NumberDeck. You can maximize and minimize any active windows with the help of this option.

#### How to bind windows?

- Yup, you need top open NumberDeck
- Click on your number of choice which you want to bind the window to
- Choose Windows from the option
- From the next dropdown, select any active window
- Save and enjoy!!

## 💻 Local Development

```bash
# Clone the repository
git clone https://github.com/ab-muhammad-hamza/NumberDeck.git

# Navigate to the project directory
cd NumberDeck

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 🔠 Languages and Technologies

![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)

NumberDeck is primarily built using:

- **Dart**: The core programming language used for logic and functionality.
- **Flutter**: The UI toolkit used for building natively compiled applications.
- **Win32 API**: Used for Windows-specific functionality and system interaction.

This combination allows for a performant, visually appealing, and deeply integrated Windows application.

### Dependencies

- [ffi](https://pub.dev/packages/ffi): ^2.1.2
- [win32](https://pub.dev/packages/win32): ^5.5.3
- [keyboard_event](https://pub.dev/packages/keyboard_event): ^0.3.4
- [shared_preferences](https://pub.dev/packages/shared_preferences): ^2.3.0
- [obs_websocket](https://pub.dev/packages/obs_websocket): ^5.1.0+9
- [flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker): ^1.0.3
- [window_manager](https://pub.dev/packages/window_manager): ^0.3.0

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request