This is a demo project to be attached to a macOS Accessibility bug report to Apple.

### Bug Description

Starting with macOS 15 Sequoia, if one application A adds an Accessibility observer to another application B and starts listening to the `AXUIElementDestroyed` notification of the top-level element (that is, the application instance), any other application C that also adds an Accessibility observer to application B will no longer receive `AXUIElementDestroyed`notifications, if they were registered on individual (non top-level-element) elements of application B.

This is a serious bug in the Accessibility API as it allows one application to break delivery of crucial Accessibility notifications to all other applications.

### How to use

This project consists of _two targets_ required for reproduction of the bug:
1. An app that registers for the `AXUIElementDestroyed` observer on the _top-level element_ of another app to trigger the bug
2. An app that registers for the `AXUIElementDestroyed` observer on _window elements_ of another app to suffer from the bug

Both targets need to be running and configured to observe the same process. Please see the instructions within the running apps for more detailed info.
