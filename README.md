# Menubar Balance

A lightweight macOS menu bar app that shows your current AI provider billing balances at a glance. It runs silently in the background and scrapes each provider's billing page to keep your usage costs up to date — no browser tab required.

## Features

- **Multi-provider:** Track API balances for ChatGPT, Claude (enterprise usage), OpenRouter, and OpenCode Zen side by side in the menu bar
- **Configurable:** Enable/disable providers and customize each one's URL and short label in the Providers window
- **Auto-Refresh:** Customisable refresh intervals (1, 2, 5, 10, 15, 30, or 60 minutes)
- **Open at Login:** Optionally launch the app automatically when you log in
- **Auth Handling:** A built-in web view appears when a provider needs you to log in or authenticate

## Building (step by step)

No prior build experience needed. You only need a Mac with **Xcode** installed ([free from the Mac App Store](https://apps.apple.com/us/app/xcode/id497799835)) — it provides the Swift compiler and asset tools this app uses. However, you may still need to run `xcode-select --install` in the Terminal before continuing with step 3.

1. **Open Terminal:** press `Cmd + Space` to open Spotlight search, type `Terminal`, and press Return.
2. **Download the code:** In Terminal, paste this and press Return.
   
   ```bash
   git clone https://github.com/iaian7/MacOS-MenubarBalance.git
   cd MacOS-MenubarBalance
   ```
   
   **Line 1** downloads the latest source code to the root of your user directory, don't worry, you can delete it after building the app!
   **Line 2** navigates into the downloaded folder so we're ready to build the code.
3. **Build the app:** this creates `MenubarBalance.app` in the same folder.

   ```bash
   ./build.sh
   ```
   Once completed, you can quit the Terminal app.
4. **Launch it:** open up a Finder window and navigate to your user directory, you'll find the app inside the `MacOS-MenubarBalance` folder. Drag `MenubarBalance.app` into your `/Applications` or `/Users/USERNAME/Applications` folder and then open it. An icon will appear in your menu bar; click it to open the menu and select `Show Providers Window…` to configure the accounts you want to monitor. That's it!

## How it works

The app loads each enabled provider's billing page in a hidden `WKWebView` and runs a small JavaScript snippet to extract the dollar amount, which it shows in the menu bar. If a provider needs you to sign in, its web view comes to the foreground so you can authenticate.
