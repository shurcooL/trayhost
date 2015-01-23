// +build linux darwin

package trayhost

import "C"

func addMenuItem(id int, item MenuItem) {
	enabled := (item.Enabled == nil) || item.Enabled()
	cAddMenuItem((C.int)(id), C.CString(item.Title), cbool(!enabled))
}
