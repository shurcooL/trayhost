#import <Cocoa/Cocoa.h>

NSMenu * appMenu;
char * clipboardString;

extern void tray_callback(int itemId);
extern BOOL tray_enabled(int itemId);
extern struct image invert_png_image(struct image img);

@interface ManageHandler : NSObject<NSUserNotificationCenterDelegate>
- (void)manage:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification;
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification;
@end

ManageHandler * uncDelegate;

@implementation ManageHandler
- (void)manage:(id)sender {
    tray_callback([[sender representedObject] intValue]);
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    //NSLog(@"in tray.m validateMenuItem\n");
    return tray_enabled([[menuItem representedObject] intValue]);
}
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m shouldPresentNotification\n");
    return YES;
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m didActivateNotification\n");
    [center removeDeliveredNotification: notification];
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m didDeliverNotification\n");
    //[center removeDeliveredNotification: notification];

    NSTimeInterval timeout = [[[notification userInfo] objectForKey:@"timeout"] doubleValue];
    if (timeout > 0.0) {
        NSLog(@"starting timer (timeout = %f) for %p\n", timeout, notification);
        [NSTimer scheduledTimerWithTimeInterval:timeout
                                         target:uncDelegate
                                       selector:@selector(clearNotificationTimer:)
                                       userInfo:notification
                                        repeats:NO];
    }
}
- (void)clearNotificationTimer:(NSTimer *)timer {
    NSUserNotification * notification = [timer userInfo];
    NSLog(@"in clearNotificationTimer %p\n", notification);
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: notification];
}
@end

void add_menu_item(int itemId, const char * title, int disabled) {
    NSString * manageTitle = [NSString stringWithUTF8String:title];
    NSMenuItem * menuItem = [[[NSMenuItem alloc] initWithTitle:manageTitle
                                action:@selector(manage:) keyEquivalent:@""]
                                autorelease];

    [menuItem setRepresentedObject:[NSNumber numberWithInt:itemId]];
    [menuItem setTarget:uncDelegate];
    [appMenu addItem:menuItem];
}

void add_separator_item() {
    [appMenu addItem:[NSMenuItem separatorItem]];
}

void native_loop() {
    [NSApp run];
}

void exit_loop() {
    // Clear all notifications.
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];

    [NSApp stop:nil];
}

int init(const char * title, unsigned char imageDataBytes[], unsigned int imageDataLen) {
    [NSAutoreleasePool new];

    [NSApplication sharedApplication];

    // This is needed to avoid having a dock icon (and entry in Cmd+Tab list).
    // [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    // However, it causes the tooltip to not appear. So LSUIElement should be used instead.

    appMenu = [[NSMenu new] autorelease];

    // Set self as NSUserNotificationCenter delegate.
    uncDelegate = [[ManageHandler alloc] init];
    NSLog(@"[NSUserNotificationCenter defaultUserNotificationCenter] -> %p", [NSUserNotificationCenter defaultUserNotificationCenter]);
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate: uncDelegate];

    // If we were opened from a user notification, do the corresponding action.
    /*{
        NSUserNotification * launchNotification = [[aNotification userInfo] objectForKey: NSApplicationLaunchUserNotificationKey];
        if (launchNotification)
            [self userNotificationCenter: nil didActivateNotification: launchNotification];
    }*/

    NSSize iconSize = NSMakeSize(16, 16);
    NSImage * icon = [[NSImage alloc] initWithSize:iconSize];
    NSData * iconData = [NSData dataWithBytes:imageDataBytes length:imageDataLen];
    [icon addRepresentation:[NSBitmapImageRep imageRepWithData:iconData]];

    struct image img;
    img.kind = IMAGE_KIND_PNG;
    img.bytes = imageDataBytes;
    img.length = imageDataLen;
    img = invert_png_image(img);

    NSImage * icon2 = [[NSImage alloc] initWithSize:iconSize];
    NSData * icon2Data = [NSData dataWithBytes:img.bytes length:img.length];
    [icon2 addRepresentation:[NSBitmapImageRep imageRepWithData:icon2Data]];

    NSStatusItem * statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    [statusItem setMenu:appMenu];
    [statusItem setImage:icon];
    [statusItem setAlternateImage:icon2];
    [statusItem setHighlightMode:YES];
    [statusItem setToolTip:[NSString stringWithUTF8String:title]];

    return 0;
}

void set_clipboard_string(const char * string) {
    NSArray * types = [NSArray arrayWithObjects:NSPasteboardTypeString, nil];

    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:types owner:nil];
    [pasteboard setString:[NSString stringWithUTF8String:string]
                  forType:NSPasteboardTypeString];
}

const char * get_clipboard_string() {
    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];

    if (![[pasteboard types] containsObject:NSPasteboardTypeString]) {
        return NULL;
    }

    NSString * object = [pasteboard stringForType:NSPasteboardTypeString];
    if (!object) {
        return NULL;
    }

    free(clipboardString);
    clipboardString = strdup([object UTF8String]);

    return clipboardString;
}

struct image get_clipboard_image() {
    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    NSData * object = NULL;

    struct image img;
    img.kind = 0;
    img.bytes = NULL;
    img.length = 0;

    // TODO: Fix memory leak.
    if ([[pasteboard types] containsObject:NSPasteboardTypePNG] &&
        (object = [pasteboard dataForType:NSPasteboardTypePNG]) != NULL) {

        img.kind = IMAGE_KIND_PNG;
        img.bytes = [object bytes];
        img.length = [object length];
    } else if ([[pasteboard types] containsObject:NSPasteboardTypeTIFF] &&
        (object = [pasteboard dataForType:NSPasteboardTypeTIFF]) != NULL) {

        img.kind = IMAGE_KIND_TIFF;
        img.bytes = [object bytes];
        img.length = [object length];
    }

    return img;
}

void display_notification(const char * title, const char * body, double timeout) {
    NSUserNotification * notification = [[NSUserNotification alloc] init];
    [notification setTitle: [NSString stringWithUTF8String:title]];
    [notification setInformativeText: [NSString stringWithUTF8String:body]];
    [notification setSoundName: NSUserNotificationDefaultSoundName];

    NSDictionary * dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:timeout] forKey:@"timeout"];
    [notification setUserInfo: dictionary];

    NSUserNotificationCenter * center = [NSUserNotificationCenter defaultUserNotificationCenter];
    [center deliverNotification: notification];
    //[center removeDeliveredNotification: notification];
}
