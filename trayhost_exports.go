package trayhost

import (
	"log"
	"reflect"
	"unsafe"
)

/*
#include <stdlib.h>
#include "platform/common.h"
*/
import "C"

//export tray_callback
func tray_callback(itemId C.int) {
	if itemId < 0 {
		log.Println("tray click")
		return
	}

	item := menuItems[itemId]
	if item.Handler != nil {
		item.Handler()
	}
}

//export tray_enabled
func tray_enabled(itemId C.int) C.int {
	item := menuItems[itemId]

	return cbool(item.Enabled == nil || item.Enabled())
}

//export notification_callback
func notification_callback(notificationId C.int) {
	if notificationId < 0 {
		log.Println("notificationId < 0:", notificationId)
		return
	}

	notification := notifications[notificationId]
	if notification.Handler != nil {
		notification.Handler()
	}
}

func create_image(image Image) (C.struct_image, func()) {
	var img C.struct_image

	if image.Kind == "" || len(image.Bytes) == 0 {
		return img, func() {}
	}

	// Copy the image data into unmanaged memory.
	cImageKind := C.CString(string(image.Kind))
	cImageData := C.malloc(C.size_t(len(image.Bytes)))
	freeImg := func() {
		C.free(unsafe.Pointer(cImageKind))
		C.free(cImageData)
	}
	var cImageDataSlice []C.uchar
	sliceHeader := (*reflect.SliceHeader)(unsafe.Pointer(&cImageDataSlice))
	sliceHeader.Cap = len(image.Bytes)
	sliceHeader.Len = len(image.Bytes)
	sliceHeader.Data = uintptr(cImageData)
	for i, b := range image.Bytes {
		cImageDataSlice[i] = C.uchar(b)
	}

	img.kind = cImageKind
	img.bytes = unsafe.Pointer(&cImageDataSlice[0])
	img.length = C.int(len(image.Bytes))

	return img, freeImg
}
