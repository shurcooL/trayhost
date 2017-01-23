// Package trayhost is a cross-platform Go library to place an icon
// in the host operating system's taskbar.
//
// Platform Support
//
// -	macOS - Fully implemented and supported.
//
// -	Linux - Not implemented.
//
// -	Windows - Not implemented.
//
// Notes
//
// On macOS, for Notification Center user notifications to work, your Go binary that
// uses trayhost must be a part of a standard macOS app bundle.
//
// Most other functionality of trayhost will be available if the binary is not a part
// of app bundle, but you will get a terminal pop up, and you will not be able to
// configure some aspects of the app.
//
// Here's a minimal layout of an app bundle:
//
// 	$ tree "Trayhost Example.app"
// 	Trayhost\ Example.app
// 	└── Contents
// 	    ├── Info.plist
// 	    ├── MacOS
// 	    │   └── example
// 	    └── Resources
// 	        └── Icon.icns
//
// Here's a minimal Info.plist file as reference (only the entries that are needed,
// nothing extra):
//
// 	<?xml version="1.0" encoding="UTF-8"?>
// 	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
// 	<plist version="1.0">
// 	<dict>
// 		<key>CFBundleExecutable</key>
// 		<string>example</string>
// 		<key>CFBundleIconFile</key>
// 		<string>Icon</string>
// 		<key>CFBundleIdentifier</key>
// 		<string>ExampleApp</string>
// 		<key>NSHighResolutionCapable</key>
// 		<true/>
// 		<key>LSUIElement</key>
// 		<string>1</string>
// 	</dict>
// 	</plist>
//
// -	CFBundleIdentifier needs to be set to some value for Notification Center to work.
//
// -	The binary must be inside Contents/MacOS directory for Notification Center to work.
//
// -	NSHighResolutionCapable to enable Retina mode.
//
// -	LSUIElement is needed to make the app not appear in Cmd+Tab list and the dock
// while still being able to show a tooltip in the menu bar.
//
// On macOS, when you run an app bundle, the working directory of the executed process
// is the root directory (/), not the app bundle's Contents/Resources directory.
// Change directory to Resources if you need to load resources from there.
//
// 	ep, err := os.Executable()
// 	if err != nil {
// 		log.Fatalln("os.Executable:", err)
// 	}
// 	err = os.Chdir(filepath.Join(filepath.Dir(ep), "..", "Resources"))
// 	if err != nil {
// 		log.Fatalln("os.Chdir:", err)
// 	}
//
package trayhost
