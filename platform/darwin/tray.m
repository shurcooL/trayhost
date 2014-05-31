// #cgo CFLAGS: -DDARWIN -x objective-c
// #cgo LDFLAGS: -framework Cocoa
#import <Cocoa/Cocoa.h>

NSMenu* appMenu;
char* clipboardString;

extern void tray_callback(int itemId);
extern struct image invert_png_image(struct image img);

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
    [menuItem setEnabled:!(BOOL)disabled];
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

int init(const char* title, unsigned char imageDataBytes[], unsigned int imageDataLen)
{
    [NSAutoreleasePool new];

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];

    appMenu = [[NSMenu new] autorelease];
    [appMenu setAutoenablesItems:NO];

    NSSize iconSize = NSMakeSize(16, 16);
    NSImage* icon = [[NSImage alloc] initWithSize:iconSize];
    NSData* iconData = [NSData dataWithBytes:imageDataBytes length:imageDataLen];
    [icon addRepresentation:[NSBitmapImageRep imageRepWithData:iconData]];

    struct image img;
    img.kind = IMAGE_KIND_PNG;
    img.bytes = imageDataBytes;
    img.length = imageDataLen;
    img = invert_png_image(img);

    NSImage* icon2 = [[NSImage alloc] initWithSize:iconSize];
    NSData* icon2Data = [NSData dataWithBytes:img.bytes length:img.length];
    [icon2 addRepresentation:[NSBitmapImageRep imageRepWithData:icon2Data]];

    NSStatusItem* statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    [statusItem setMenu:appMenu];
    [statusItem setImage:icon];
    [statusItem setAlternateImage:icon2];
    [statusItem setHighlightMode:YES];
    [statusItem setToolTip:[NSString stringWithUTF8String:title]];

    return 0;
}

void set_clipboard_string(const char* string)
{
    NSArray* types = [NSArray arrayWithObjects:NSPasteboardTypeString, nil];

    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:types owner:nil];
    [pasteboard setString:[NSString stringWithUTF8String:string]
                  forType:NSPasteboardTypeString];
}

const char* get_clipboard_string()
{
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];

    if (![[pasteboard types] containsObject:NSPasteboardTypeString]) {
        return NULL;
    }

    NSString* object = [pasteboard stringForType:NSPasteboardTypeString];
    if (!object) {
        return NULL;
    }

    free(clipboardString);
    clipboardString = strdup([object UTF8String]);

    return clipboardString;
}

struct image get_clipboard_image()
{
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    NSData* object = NULL;

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
