// #cgo CFLAGS: -DDARWIN -x objective-c
// #cgo LDFLAGS: -framework Cocoa
#import <Cocoa/Cocoa.h>

NSMenu* appMenu;

extern void tray_callback(int itemId);

@interface ManageHandler : NSObject
+ (void)manage:(id)sender;
@end

@implementation ManageHandler
+ (void)manage:(id)sender {
    tray_callback([[sender representedObject] intValue]);
}
@end

void add_menu_item(int itemId, const char *title, int disabled) {
    NSString* manageTitle = [NSString stringWithCString:title encoding:NSUTF8StringEncoding];
    NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle:manageTitle
                                action:@selector(manage:) keyEquivalent:@""]
                                autorelease];

    [menuItem setRepresentedObject:[NSNumber numberWithInt:itemId]];
    [menuItem setTarget:[ManageHandler class]];
    [menuItem setEnabled: !(BOOL)disabled];
    [appMenu addItem:menuItem];
}

void add_separator_item() {
    [appMenu addItem:[NSMenuItem separatorItem]];
}

void native_loop() {
    [NSApp run];
}

void exit_loop() {
    [NSApp stop:nil];
}

int init(const char *title, unsigned char imageDataBytes[], unsigned int imageDataLen) {

    [NSAutoreleasePool new];

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];

    appMenu = [[NSMenu new] autorelease];
    [appMenu setAutoenablesItems: NO];

    NSData *iconData = [NSData dataWithBytes:imageDataBytes length:imageDataLen];
    NSImage *icon = [[NSImage alloc] initWithData:iconData];

    NSStatusItem* statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:appMenu];
    [statusItem setImage:icon];
    [statusItem setHighlightMode:NO];

    return 0;
}
