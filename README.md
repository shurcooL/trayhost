# trayhost [![GoDoc](https://godoc.org/github.com/shurcooL/trayhost?status.svg)](https://godoc.org/github.com/shurcooL/trayhost)

Package trayhost is a cross-platform Go library to place an icon
in the host operating system's taskbar.

Platform Support
----------------

-	OS X - Fully implemented and supported.
-	Linux - Not implemented.
-	Windows - Not implemented.

Notes
-----

On OS X, for Notification Center user notifications to work, your Go binary that uses `trayhost` must be a part of a standard OS X app bundle.

Here's a minimal layout of an app bundle:

```
$ tree "Trayhost Sample.app"
Trayhost\ Sample.app
└── Contents
    ├── Info.plist
    ├── MacOS
    │   └── your_Go_binary
    └── Resources
        └── Icon.icns
```

Here's a minimal `Info.plist` file as reference (only the entries that are needed, nothing extra):

```XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>your_Go_binary</string>
	<key>CFBundleIconFile</key>
	<string>Icon</string>
	<key>CFBundleIdentifier</key>
	<string>YourAppName</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<string>1</string>
</dict>
</plist>
```

-	`CFBundleIdentifier` needs to be set to some value for Notification Center to work.
-	`NSHighResolutionCapable` to enable Retina mode.
-	`LSUIElement` is needed to make the app not appear in Cmd+Tab list and the dock while still being able to show a tooltip in the menu bar.

Most other functionality of `trayhost` will be available if the binary is not a part of app bundle, but you will get a terminal pop up, and you will not be able to configure some aspects of the app.

Installation
------------

```bash
go get -u github.com/shurcooL/trayhost
```
