package trayhost

import (
	"errors"
	"reflect"
	"unsafe"
)

/*
#cgo linux pkg-config: gtk+-2.0
#cgo linux CFLAGS: -DLINUX -I/usr/include/libappindicator-0.1
#cgo linux LDFLAGS: -ldl
#cgo windows CFLAGS: -DWIN32
#cgo darwin CFLAGS: -DDARWIN -x objective-c
#cgo darwin LDFLAGS: -framework Cocoa
#include <stdlib.h>
#include "platform/platform.h"
*/
import "C"

var menuItems []MenuItem

type MenuItem struct {
	Title    string
	Disabled bool
	Handler  func()
}

// Run the host system's event loop
func Initialize(title string, imageData []byte, items []MenuItem) {
	cTitle := C.CString(title)
	defer C.free(unsafe.Pointer(cTitle))

	// Copy the image data into unmanaged memory
	cImageData := C.malloc(C.size_t(len(imageData)))
	defer C.free(cImageData)
	var cImageDataSlice []C.uchar
	sliceHeader := (*reflect.SliceHeader)(unsafe.Pointer(&cImageDataSlice))
	sliceHeader.Cap = len(imageData)
	sliceHeader.Len = len(imageData)
	sliceHeader.Data = uintptr(cImageData)

	for i, v := range imageData {
		cImageDataSlice[i] = C.uchar(v)
	}

	// Initialize menu
	C.init(cTitle, &cImageDataSlice[0], C.uint(len(imageData)))

	menuItems = items
	for id, item := range menuItems {
		addItem(id, item)
	}
}

func EnterLoop() {
	C.native_loop()
}

func Exit() {
	C.exit_loop()
}

// Creates a separator MenuItem.
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
	} else {
		return 0
	}
}

// SetClipboardString sets the system clipboard to the specified UTF-8 encoded
// string.
//
// This function may only be called from the main thread.
func SetClipboardString(str string) {
	cp := C.CString(str)
	defer C.free(unsafe.Pointer(cp))

	C.set_clipboard_string(cp)
}

// GetClipboardString returns the contents of the system clipboard, if it
// contains or is convertible to a UTF-8 encoded string.
//
// This function may only be called from the main thread.
func GetClipboardString() (string, error) {
	cs := C.get_clipboard_string()
	if cs == nil {
		return "", errors.New("Can't get clipboard string.")
	}

	return C.GoString(cs), nil
}

// GetClipboardString returns the contents of the system clipboard, if it
// contains or is convertible to an image.
//
// This function may only be called from the main thread.
//
// TODO: Currently assumes PNG. Support other types, return type.
func GetClipboardImage() ([]byte, error) {
	img := C.get_clipboard_image()
	if img.bytes == nil {
		return nil, errors.New("Can't get clipboard image.")
	}

	return C.GoBytes(img.bytes, img.length), nil
}
