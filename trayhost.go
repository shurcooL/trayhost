package trayhost

import (
	"time"
	"unsafe"
)

/*
#cgo darwin CFLAGS: -DDARWIN -x objective-c
#cgo darwin LDFLAGS: -framework Cocoa

#cgo linux pkg-config: gtk+-3.0 appindicator3-0.1 libnotify
#cgo linux CFLAGS: -DLINUX -Wno-deprecated-declarations
#cgo linux LDFLAGS: -ldl

#cgo windows CFLAGS: -DWIN32

#include <stdlib.h>
#include "platform/common.h"
#include "platform/platform.h"
*/
import "C"

var menuItems []MenuItem

// MenuItem is a menu item.
type MenuItem struct {
	// Title is the title of menu item.
	//
	// If empty, it acts as a separator. SeparatorMenuItem can be used
	// to create such separator menu items.
	Title string

	// Enabled can optionally control if this menu item is enabled or disabled.
	//
	// nil means always enabled.
	Enabled func() bool

	// Handler is triggered when the item is activated. nil means no handler.
	Handler func()
}

// Initialize sets up the application properties.
// imageData is the icon image in PNG format.
func Initialize(title string, imageData []byte, items []MenuItem) {
	cTitle := C.CString(title)
	defer C.free(unsafe.Pointer(cTitle))
	img, freeImg := create_image(Image{Kind: "png", Bytes: imageData})
	defer freeImg()

	// Initialize menu.
	C.init(cTitle, img)

	menuItems = items
	for id, item := range menuItems {
		addItem(id, item)
	}
}

// EnterLoop enters main loop.
func EnterLoop() {
	C.native_loop()
}

// Exit exits the application. It can be called from a MenuItem handler.
func Exit() {
	C.exit_loop()
}

// init widget for running in other gtk_main loop
func InitWidget() {
	C.external_main_loop()
}

// SeparatorMenuItem creates a separator MenuItem.
func SeparatorMenuItem() MenuItem { return MenuItem{Title: ""} }

func addItem(id int, item MenuItem) {
	if item.Title == "" {
		C.add_separator_item()
	} else {
		// ignore errors
		addMenuItem(id, item)
	}
}

func cAddMenuItem(id C.int, title *C.char, disabled C.int) {
	C.add_menu_item(id, title, disabled)
}

func cbool(b bool) C.int {
	if b {
		return 1
	}
	return 0
}

// ---

// SetClipboardText sets the system clipboard to the specified UTF-8 encoded
// string.
//
// This function may only be called from the main thread.
func SetClipboardText(text string) {
	cp := C.CString(text)
	defer C.free(unsafe.Pointer(cp))

	C.set_clipboard_string(cp)
}

// ImageKind is a file extension in lower case: "png", "jpg", "tiff", etc. Empty string means no image.
type ImageKind string

// Image is an encoded image of certain kind.
type Image struct {
	Kind  ImageKind
	Bytes []byte
}

// ClipboardContent holds the contents of system clipboard.
type ClipboardContent struct {
	Text  string
	Image Image
	Files []string
}

// GetClipboardContent returns the contents of the system clipboard, if it
// contains or is convertible to a UTF-8 encoded string, image, and/or files.
//
// This function may only be called from the main thread.
func GetClipboardContent() (ClipboardContent, error) {
	var cc ClipboardContent

	ccc := C.get_clipboard_content()
	if ccc.text != nil {
		cc.Text = C.GoString(ccc.text)
	}
	if ccc.image.kind != nil {
		cc.Image = Image{
			Kind:  ImageKind(C.GoString(ccc.image.kind)),
			Bytes: C.GoBytes(ccc.image.bytes, ccc.image.length),
		}
	}
	if ccc.files.count > 0 {
		cc.Files = make([]string, int(ccc.files.count))
		for i := 0; i < int(ccc.files.count); i++ {
			var x *C.char
			p := (**C.char)(unsafe.Pointer(uintptr(unsafe.Pointer(ccc.files.names)) + uintptr(i)*unsafe.Sizeof(x)))
			cc.Files[i] = C.GoString(*p)
		}
	}

	return cc, nil
}

// ---

// TODO: Garbage collection. Really only need this until the notification is cleared, so its Handler is accessible.
var notifications []Notification

// Notification represents a user notification.
type Notification struct {
	Title string // Title of user notification.
	Body  string // Body of user notification.
	Image Image  // Image shown in the content of user notification.

	// Timeout specifies time after which the notification is cleared.
	//
	// A Timeout of zero means no timeout.
	Timeout time.Duration

	// Activation (click) handler.
	//
	// nil means no handler.
	Handler func()
}

// Display displays the user notification.
func (n Notification) Display() {
	cTitle := C.CString(n.Title)
	defer C.free(unsafe.Pointer(cTitle))
	cBody := C.CString(n.Body)
	defer C.free(unsafe.Pointer(cBody))
	img, freeImg := create_image(n.Image)
	defer freeImg()

	// TODO: Move out of Display.
	notificationId := (C.int)(len(notifications))
	notifications = append(notifications, n)

	C.display_notification(notificationId, cTitle, cBody, img, C.double(n.Timeout.Seconds()))
}

// UpdateMenu removes all current menu items, and adds new menu items.
func UpdateMenu(newMenu []MenuItem) {
	C.clear_menu_items()
	menuItems = newMenu
	for id, item := range newMenu {
		addItem(id, item)
	}
}
