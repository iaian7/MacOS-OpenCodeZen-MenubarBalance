# OpenCode Zen Menubar Balance

A lightweight macOS menu bar application that displays your current OpenCode Zen billing balance. It runs silently in the background and scrapes your billing dashboard to provide quick, up-to-date access to your usage costs.

## Features

- **Menu Bar Display:** Quickly view your current OpenCode balance without opening a browser.
- **Auto-Refresh:** Customizable refresh intervals (1, 2, 5, 10, 15, 30, or 60 minutes).
- **Open at Login:** Option to automatically launch the app when you log in.
- **Auth Handling:** Built-in web view that appears automatically if login or GitHub authentication is required.

## Building and Running

This app uses Swift and is built via a simple shell script (no Xcode project required).

1. Clone the repository.
2. Run the build script in the terminal:
   ```bash
   ./build.sh
   ```
3. The script will generate `OpenCodeBalance.app`.
4. Launch the application:
   ```bash
   open OpenCodeBalance.app
   ```

*Note: For the "Open at Login" feature to work reliably, you may need to move `OpenCodeBalance.app` to your `/Applications` folder.*

## How it works

The app uses a hidden `WKWebView` to load your specific OpenCode Zen billing page. It executes a small JavaScript snippet to extract the formatted dollar amount and updates the NSStatusItem in your menu bar. If a login wall is detected, it brings the web view window to the foreground so you can authenticate.
