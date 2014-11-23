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

//export invert_png_image
func invert_png_image(img C.struct_image) C.struct_image {
	imageData := invertPngImage(C.GoBytes(img.bytes, img.length))

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

	return C.struct_image{
		kind:   C.char(ImageKindPng),
		bytes:  unsafe.Pointer(&cImageDataSlice[0]),
		length: C.int(len(imageData)),
	}
}

func invertPngImage(imageData []byte) []byte {
	m, _, err := image.Decode(bytes.NewReader(imageData))
	if err != nil {
		panic(err)
	}

	InvertImageNrgba(m.(*image.NRGBA))

	var buf bytes.Buffer
	err = png.Encode(&buf, m)
	if err != nil {
		panic(err)
	}

	return buf.Bytes()
}

func InvertImageNrgba(nrgba *image.NRGBA) {
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
