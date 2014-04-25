// +build windows

package trayhost

import "C"

import (
	"syscall"
	"unsafe"
)

func addMenuItem(id int, item MenuItem) {
	// ignore errors
	titlePtr, _ := syscall.UTF16PtrFromString(item.Title)
	cAddMenuItem((C.int)(id), (*C.char)(unsafe.Pointer(titlePtr)), cbool(item.Disabled))
}
