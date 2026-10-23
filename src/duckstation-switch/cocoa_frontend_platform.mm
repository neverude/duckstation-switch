// SPDX-FileCopyrightText: 2019-2023 Connor McLaughlin <stenzek@gmail.com>
// SPDX-License-Identifier: (GPL-3.0 OR CC-BY-NC-ND-4.0)

#include "cocoa_frontend_platform.h"
#include "cocoa_key_names.h"
#include "frontend_host.h"

#include "core/host.h"

#include "util/cocoa_tools.h"
#include "util/imgui_manager.h"

#include "common/log.h"
#include "common/scoped_guard.h"
#include "common/string_util.h"
#include "common/threading.h"

Log_SetChannel(CocoaFrontendPlatform);

constexpr NSWindowStyleMask WINDOWED_STYLE = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

@implementation CocoaFrontendView

- (BOOL)acceptsFirstResponder {
  return YES;
}
- (BOOL)canBecomeKeyView {
  return YES;
}
- (void)mouseDown:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(0, true);
}
- (void)rightMouseDown:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(1, true);
}
- (void)otherMouseDown:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(static_cast<s32>(event.buttonNumber), true);
}

- (void)mouseUp:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(0, false);
}
- (void)rightMouseUp:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(1, false);
}
- (void)otherMouseUp:(NSEvent *)event {
  FrontendHost::ProcessPlatformMouseButtonEvent(static_cast<s32>(event.buttonNumber), false);
}

- (void)mouseMoved:(NSEvent *)event {
  // Flip for lower-left origin.
  const NSView* contentView = self;
  const NSPoint pt = [contentView convertPointToBacking:[event locationInWindow]];
  const NSSize size = [contentView convertSizeToBacking:contentView.frame.size];
  const float local_x = pt.x;
  const float local_y = size.height - pt.y;
  FrontendHost::ProcessPlatformMouseMoveEvent(local_x, local_y);
}

- (void)keyDown:(NSEvent *)event {
  [super keyDown:event];
  if (ImGuiManager::WantsTextInput() && event.characters && event.characters.length > 0)
  {
    ImGuiManager::AddTextInput([event.characters UTF8String]);
  }
  
  if (!event.isARepeat)
    FrontendHost::ProcessPlatformKeyEvent(static_cast<s32>(event.keyCode), true);
}

- (void)keyUp:(NSEvent *)event {
  [super keyUp:event];
  FrontendHost::ProcessPlatformKeyEvent(static_cast<s32>(event.keyCode), false);
}

- (void)windowDidEndLiveResize:(NSNotification *)notif
{
  const NSSize size = [self convertSizeToBacking:self.frame.size];
  FrontendHost::ProcessPlatformWindowResize(static_cast<s32>(size.width), static_cast<s32>(size.height), 1.0f);
}
@end

CocoaFrontendPlatform::CocoaFrontendPlatform() = default;

CocoaFrontendPlatform::~CocoaFrontendPlatform()
{
  if (m_window)
  {
    [m_window release];
    m_window = nil;
  }
}

bool CocoaFrontendPlatform::Initialize()
{
  [NSApplication sharedApplication];
  
  // Needed for keyboard in put.
  const ProcessSerialNumber psn = {0, kCurrentProcess};
  TransformProcessType(&psn, kProcessTransformToForegroundApplication);
  return true;
}

void CocoaFrontendPlatform::ReportError(const std::string_view& title, const std::string_view& message)
{
  if (![NSThread isMainThread])
  {
    dispatch_sync(dispatch_get_main_queue(), [this, &title, &message]() { ReportError(title, message); });
    return;
  }
  
  @autoreleasepool {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText: CocoaTools::StringViewToNSString(title)];
    [alert setInformativeText: CocoaTools::StringViewToNSString(message)];
    [alert runModal];
  }
}

bool CocoaFrontendPlatform::ConfirmMessage(const std::string_view& title, const std::string_view& message)
{
  if (![NSThread isMainThread])
  {
    bool result = false;
    dispatch_sync(dispatch_get_main_queue(), [this, &title, &message, &result]() { result = ConfirmMessage(title, message); });
    return result;
  }
  
  @autoreleasepool {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText: CocoaTools::StringViewToNSString(title)];
    [alert setInformativeText: CocoaTools::StringViewToNSString(message)];
    [alert addButtonWithTitle:@"Yes"];
    [alert addButtonWithTitle:@"No"];
    return ([alert runModal] == 0);
  }
}

void CocoaFrontendPlatform::SetDefaultConfig(SettingsInterface& si)
{
  // noop
}

bool CocoaFrontendPlatform::CreatePlatformWindow(std::string title)
{
  @autoreleasepool {
    s32 window_x, window_y, window_width, window_height;
    const bool has_window_geom = FrontendHost::GetSavedPlatformWindowGeometry(&window_x, &window_y, &window_width, &window_height);
    if (!has_window_geom)
    {
      window_width = DEFAULT_WINDOW_WIDTH;
      window_height = DEFAULT_WINDOW_HEIGHT;
    }
    
    m_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, static_cast<CGFloat>(window_width), static_cast<CGFloat>(window_height))
                                           styleMask:WINDOWED_STYLE
                                             backing:NSBackingStoreBuffered defer:YES];
    
    CocoaFrontendView* view = [[[CocoaFrontendView alloc] init] autorelease];
    [m_window setDelegate:view];
    [m_window setContentView:view];
    
    if (!has_window_geom)
      [m_window center];
    else
      [m_window setFrameOrigin:NSMakePoint(static_cast<CGFloat>(window_x), static_cast<CGFloat>(window_y))];
    
    [m_window setTitle: [NSString stringWithUTF8String:title.c_str()]];
    [m_window setAcceptsMouseMovedEvents:YES];
    [m_window setReleasedWhenClosed:NO];
    [m_window setIsVisible:TRUE];
    [m_window makeKeyAndOrderFront:nil];
  }
  
  if (m_fullscreen.load(std::memory_order_acquire))
    SetFullscreen(true);
  
  return true;
}

bool CocoaFrontendPlatform::HasPlatformWindow() const
{
  return (m_window != NULL);
}

void CocoaFrontendPlatform::DestroyPlatformWindow()
{
  if (m_window == nil)
    return;
  
  const CGPoint frame_origin = m_window.frame.origin;
  const CGSize content_size = m_window.contentView.frame.size;
  
  if (!m_fullscreen.load(std::memory_order_acquire))
  {
    FrontendHost::SavePlatformWindowGeometry(static_cast<s32>(frame_origin.x), static_cast<s32>(frame_origin.y),
                                          static_cast<s32>(content_size.width), static_cast<s32>(content_size.height));
  }
  
  [m_window close];
  [m_window release];
  m_window = nil;
}

std::optional<WindowInfo> CocoaFrontendPlatform::GetPlatformWindowInfo()
{
  if (m_window == nil)
    return std::nullopt;
  
  NSView* contentView = [m_window contentView];
  const NSSize size = [contentView convertSizeToBacking:contentView.frame.size];

  WindowInfo wi;
  wi.surface_width = static_cast<u32>(size.width);
  wi.surface_height = static_cast<u32>(size.height);
  wi.surface_scale = m_window_scale;
  wi.type = WindowInfo::Type::MacOS;
  wi.window_handle = static_cast<void*>(m_window.contentView);
  return wi;
}

void CocoaFrontendPlatform::SetPlatformWindowTitle(std::string title)
{
  dispatch_async(dispatch_get_main_queue(), [this, title = std::move(title)]() {
    if (!m_window)
      return;
    
    @autoreleasepool {
      [m_window setTitle: [NSString stringWithUTF8String:title.c_str()]];
    }
  });
}

std::optional<u32> CocoaFrontendPlatform::ConvertHostKeyboardStringToCode(const std::string_view& str)
{
  std::optional<unsigned short> converted(CocoaKeyNames::GetKeyCodeForName(str));
  return converted.has_value() ? std::optional<u32>(static_cast<u32>(converted.value())) : std::nullopt;
}

std::optional<std::string> CocoaFrontendPlatform::ConvertHostKeyboardCodeToString(u32 code)
{
  const char* converted = CocoaKeyNames::GetKeyName(static_cast<unsigned short>(code));
  return converted ? std::optional<std::string>(converted) : std::nullopt;
}

void CocoaFrontendPlatform::RunMessageLoop()
{
  [NSApp run];
}

void CocoaFrontendPlatform::ExecuteInMessageLoop(std::function<void()> func)
{
  dispatch_async(dispatch_get_main_queue(), [func = std::move(func)]() {
    func();
  });
}

void CocoaFrontendPlatform::QuitMessageLoop()
{
  [NSApp stop:nil];
}

void CocoaFrontendPlatform::SetFullscreen(bool enabled)
{
  Log_ErrorPrint("SetFullscreen() not implemented.");
}

bool CocoaFrontendPlatform::RequestRenderWindowSize(s32 new_window_width, s32 new_window_height)
{
  dispatch_async(dispatch_get_main_queue(), [this, new_window_width, new_window_height]() {
    if (!m_window)
      return;
    
    @autoreleasepool {
      [m_window setContentSize:NSMakeSize(static_cast<CGFloat>(new_window_width), static_cast<CGFloat>(new_window_height))];
    }
  });
  
  return true;
}

bool CocoaFrontendPlatform::OpenURL(const std::string_view& url)
{
  Log_ErrorPrint("OpenURL() not implemented.");
  return false;
}

bool CocoaFrontendPlatform::CopyTextToClipboard(const std::string_view& text)
{
  Log_ErrorPrint("CopyTextToClipboard() not implemented.");
  return false;
}

std::unique_ptr<FrontendPlatform> FrontendPlatform::CreateCocoaPlatform()
{
  std::unique_ptr<CocoaFrontendPlatform> ret(new CocoaFrontendPlatform());
  if (!ret->Initialize())
    return {};

  return ret;
}
