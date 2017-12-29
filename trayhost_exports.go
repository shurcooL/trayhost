package trayhost

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
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

//export invert_png_image
func invert_png_image(img C.struct_image) C.struct_image {
	imageData := invertPngImage(C.GoBytes(img.bytes, img.length))
	img, _ = create_image(Image{Kind: "png", Bytes: imageData})
	return img
}

func invertPngImage(imageData []byte) []byte {
	m, _, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		panic(err)
	}

	switch m.(type) {
	case *image.NRGBA:
		invertImageNrgba(m.(*image.NRGBA))
	}

	var buf bytes.Buffer
	err = png.Encode(&buf, m)
	if err != nil {
		panic(err)
	}

	return buf.Bytes()
}

func invertImageNrgba(nrgba *image.NRGBA) {
	bounds := nrgba.Bounds()
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			c := nrgba.At(x, y).(color.NRGBA)
			c.R = 255 - c.R
			c.G = 255 - c.G
			c.B = 255 - c.B
			nrgba.SetNRGBA(x, y, c)
		}
	}
}
