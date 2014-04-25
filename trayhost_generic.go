// +build linux darwin

package trayhost

import "C"

func addMenuItem(id int, item MenuItem) {
	cAddMenuItem((C.int)(id), C.CString(item.Title), cbool(item.Disabled))
}
