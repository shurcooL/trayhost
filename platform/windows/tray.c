#include <stdio.h>
#include <windows.h>
#include <shellapi.h>

#define WM_MYMESSAGE (WM_USER + 1)

#define MAX_LOADSTRING 100

HINSTANCE hInst;
HMENU hSubMenu;
TCHAR szTitle[MAX_LOADSTRING];
TCHAR szWindowClass[MAX_LOADSTRING];
wchar_t *titleWide;
NOTIFYICONDATA nid;

ATOM                MyRegisterClass(HINSTANCE hInstance);
HWND                InitInstance(HINSTANCE, int);
LRESULT CALLBACK    WndProc(HWND, UINT, WPARAM, LPARAM);

extern void tray_callback(int itemId);

void add_separator_item()
{
    AppendMenuW(hSubMenu, MF_SEPARATOR, 0, NULL);
}

void add_menu_item(int id, const char* title, int disabled)
{
    UINT uFlags = MF_STRING;
    if (disabled == TRUE) {
        uFlags |= MF_GRAYED;
    }
    AppendMenuW(hSubMenu, uFlags, id, (wchar_t*)title);
}

void clear_menu_items()
{
    int count = GetMenuItemCount(hSubMenu);
    UINT i = 0;
    for (; i < count; i++) {
        // always remove at 0 because they shift every time
        RemoveMenu(hSubMenu, 0, MF_BYPOSITION);
    }
}

void native_loop()
{
    MSG msg;
    // Main message loop:
    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
}

int init(const char * title, struct image img) {
    HWND hWnd;
    HINSTANCE hInstance = GetModuleHandle(NULL);

    // get thish shit into windows whide chars or whatever
    titleWide = (wchar_t*)calloc(strlen(title) + 1, sizeof(wchar_t));
    mbstowcs(titleWide, title, strlen(title));

    wcscpy((wchar_t*)szTitle, titleWide);
    wcscpy((wchar_t*)szWindowClass, (wchar_t*)TEXT("MyClass"));
    MyRegisterClass(hInstance);

    hWnd = InitInstance(hInstance, FALSE); // Don't show window
    if (!hWnd)
    {
        return;
    }

    // Let's load up the tray icon
    HICON hIcon;
    {
        // This is really hacky, but LoadImage won't let me load an image from memory.
        // So we have to write out a temporary file, load it from there, then delete the file.

        // From http://msdn.microsoft.com/en-us/library/windows/desktop/aa363875.aspx
        TCHAR szTempFileName[MAX_PATH+1];
        TCHAR lpTempPathBuffer[MAX_PATH+1];
        int dwRetVal = GetTempPath(MAX_PATH+1,        // length of the buffer
                                   lpTempPathBuffer); // buffer for path
        if (dwRetVal > MAX_PATH+1 || (dwRetVal == 0))
        {
            return; // Failure
        }

        //  Generates a temporary file name.
        int uRetVal = GetTempFileName(lpTempPathBuffer, // directory for tmp files
                                      TEXT("_tmpicon"), // temp file name prefix
                                      0,                // create unique name
                                      szTempFileName);  // buffer for name
        if (uRetVal == 0)
        {
            return; // Failure
        }

        // Dump the icon to the temp file
        FILE* fIcon = fopen(szTempFileName, "wb");
        fwrite(img.bytes, 1, img.length, fIcon);
        fclose(fIcon);
        fIcon = NULL;

        // Load the image from the file
        hIcon = LoadImage(NULL, szTempFileName, IMAGE_ICON, 64, 64, LR_LOADFROMFILE);

        // Delete the temp file
        remove(szTempFileName);
    }

    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = hWnd;
    nid.uID = 100;
    nid.uCallbackMessage = WM_MYMESSAGE;
    nid.hIcon = hIcon;

    strcpy(nid.szTip, title); // MinGW seems to use ANSI
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;

    Shell_NotifyIcon(NIM_ADD, &nid);

    hSubMenu = CreatePopupMenu();
    return 0;
}

void exit_loop() {
    Shell_NotifyIcon(NIM_DELETE, &nid);
    PostQuitMessage(0);
}


ATOM MyRegisterClass(HINSTANCE hInstance)
{
    WNDCLASSEX wcex;

    wcex.cbSize = sizeof(WNDCLASSEX);

    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszMenuName   = 0;
    wcex.lpszClassName  = szWindowClass;
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    return RegisterClassEx(&wcex);
}

HWND InitInstance(HINSTANCE hInstance, int nCmdShow)
{
    HWND hWnd;

    hInst = hInstance;

    hWnd = CreateWindow(szWindowClass, szTitle, WS_OVERLAPPEDWINDOW,
                        CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, hInstance, NULL);
    // hWnd = CreateWindowW(L"Krneki", L"Title", WS_OVERLAPPEDWINDOW,
    //                     CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, hInstance, NULL);

    if (!hWnd)
    {
        return 0;
    }

    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);

    return hWnd;
}

void ShowMenu(HWND hWnd)
{
    POINT p;
    GetCursorPos(&p);
    SetForegroundWindow(hWnd); // Win32 bug work-around
    TrackPopupMenu(hSubMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, p.x, p.y, 0, hWnd, NULL);
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
        case WM_COMMAND:
            tray_callback(LOWORD(wParam));
            break;
        case WM_DESTROY:
            exit_loop();
            break;
        case WM_MYMESSAGE:
            switch(lParam)
            {
                case WM_RBUTTONUP:
                    ShowMenu(hWnd);
                    break;
                case WM_LBUTTONUP:
                    tray_callback(-1);
                    break;
                default:
                    return DefWindowProc(hWnd, message, wParam, lParam);
            };
            break;
        default:
            return DefWindowProc(hWnd, message, wParam, lParam);
    }
    return 0;
}

void set_clipboard_string(const char * string) {
    // TODO: Implement.
}

struct clipboard_content get_clipboard_content() {
    // TODO: Implement.
    struct clipboard_content cc;
    return cc;
}

void display_notification(int notificationId, const char * title, const char * body, struct image img, double timeout) {
    // TODO: Implement.
}
