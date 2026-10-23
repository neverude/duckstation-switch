#include "switch_nogui_platform.h"

#include "core/host.h"

#include "common/log.h"

#include "util/gpu_device.h"
#include "util/imgui_manager.h"
#include "util/switch_exception_frame.h"

#include <switch.h>

Log_SetChannel(SwitchNoGUIPlatform);

namespace Common::PageFaultHandler {
bool PageFaultHandler(ExceptionFrameA64* ctx);
}

extern "C" {

extern char __start__;
extern char __rodata_start;

static bool ReadU64Safe(uint64_t address, uint64_t* out)
{
  if ((address & 0x7) != 0)
    return false;

  MemoryInfo info = {};
  u32 page_info = 0;
  if (R_FAILED(svcQueryMemory(&info, &page_info, address)) || info.type == MemType_Unmapped || !(info.perm & Perm_R))
    return false;

  *out = *reinterpret_cast<const uint64_t*>(address);
  return true;
}

// Writes the fault details to the SD card. Addresses are printed relative to the start of the module, so they can
// be looked up with addr2line against the matching .elf. Deliberately avoids the logger (its mutex may be held).
void HandleFault(const ExceptionFrameA64* frame, uint64_t fp, Result desc)
{
  const uint64_t base = reinterpret_cast<uint64_t>(&__start__);
  const uint64_t text_end = reinterpret_cast<uint64_t>(&__rodata_start);

  FILE* fp_out = std::fopen("sdmc:/switch/duckstation/crash.txt", "w");
  if (!fp_out)
    svcBreak(BreakReason_Panic, 0, 0);

  std::fprintf(fp_out, "DuckStation Switch crash report\n");
  std::fprintf(fp_out, "module base 0x%llx, text size 0x%llx\n", static_cast<unsigned long long>(base),
               static_cast<unsigned long long>(text_end - base));
  std::fprintf(fp_out, "reason 0x%x (%u-%04u), esr 0x%x, far 0x%llx\n", desc, 2000 + (desc & 0x1FF),
               (desc >> 9) & 0x1FFF, frame->esr, static_cast<unsigned long long>(frame->far));
  std::fprintf(fp_out, "pc 0x%llx (%s +0x%llx)\n", static_cast<unsigned long long>(frame->pc),
               (frame->pc >= base && frame->pc < text_end) ? "module" : "other",
               static_cast<unsigned long long>(frame->pc - base));
  std::fprintf(fp_out, "lr 0x%llx (+0x%llx), sp 0x%llx\n", static_cast<unsigned long long>(frame->lr),
               static_cast<unsigned long long>(frame->lr - base), static_cast<unsigned long long>(frame->sp));
  for (int i = 0; i < 9; i++)
    std::fprintf(fp_out, "x%d 0x%llx\n", i, static_cast<unsigned long long>(frame->x[i]));

  std::fprintf(fp_out, "stack frames (module-relative):\n");
  uint64_t lr = frame->lr;
  for (int frame_num = 0; frame_num < 24; frame_num++)
  {
    std::fprintf(fp_out, "  #%d +0x%llx\n", frame_num, static_cast<unsigned long long>(lr - base));

    uint64_t next_fp = 0, next_lr = 0;
    if (!ReadU64Safe(fp, &next_fp) || !ReadU64Safe(fp + 8, &next_lr) || next_fp == 0)
      break;

    lr = next_lr;
    fp = next_fp;
  }

  std::fclose(fp_out);
  svcBreak(BreakReason_Panic, 0, 0);
}

static_assert(sizeof(ExceptionFrameA64) == 0x78);

alignas(16) uint8_t switch_exception_stack_top[0x8000];

void switch_exception_handler(Result reason, ExceptionFrameA64* frame, u64 fp)
{
  if (Common::PageFaultHandler::PageFaultHandler(frame))
    return;
  HandleFault(frame, fp, reason);
}
}

std::unique_ptr<NoGUIPlatform> NoGUIPlatform::CreateSwitchPlatform()
{
  std::unique_ptr<SwitchNoGUIPlatform> platform(std::make_unique<SwitchNoGUIPlatform>());
  if (!platform->Initialize())
    platform.reset();
  return platform;
}

SwitchNoGUIPlatform::SwitchNoGUIPlatform()
{
  m_message_loop_running.store(true, std::memory_order_release);
}

SwitchNoGUIPlatform::~SwitchNoGUIPlatform()
{
  // The hook holds a pointer to this object, do not leave it registered.
  appletUnhook(&m_applet_cookie);
}

void SwitchNoGUIPlatform::AppletModeChange(AppletHookType type)
{
  switch (type)
  {
    case AppletHookType_OnOperationMode:
    {
      std::optional<WindowInfo> wi = GetPlatformWindowInfo();
      nwindowSetDimensions(nwindowGetDefault(), wi->surface_width, wi->surface_height);
      NoGUIHost::ProcessPlatformWindowResize(wi->surface_width, wi->surface_height, wi->surface_scale);
      break;
    }
    default:
      break;
  }
}

static void AppletModeChange(AppletHookType type, void* host_interface)
{
  static_cast<SwitchNoGUIPlatform*>(host_interface)->AppletModeChange(type);
}

bool SwitchNoGUIPlatform::Initialize()
{
  appletHook(&m_applet_cookie, ::AppletModeChange, this);

  // Mesa takes the surface size from the native window. CreatePlatformWindow() is never called on Switch (the
  // window always exists), so this has to happen here, before any EGL surface is created.
  if (const std::optional<WindowInfo> wi = GetPlatformWindowInfo(); wi.has_value())
  {
    Log_InfoFmt("Setting native window size to {}x{}", wi->surface_width, wi->surface_height);
    nwindowSetDimensions(nwindowGetDefault(), wi->surface_width, wi->surface_height);
  }

  return true;
}

void SwitchNoGUIPlatform::ReportError(const std::string_view& title, const std::string_view& message)
{
  // Do not use the system error applet here: launching it crashed on firmware 21.0.1 (error 2128-0500,
  // program 0100000000001005). The message is always in the log file, and is shown on screen if the GUI is up.
  Log_ErrorFmt("{}: {}", title, message);

  if (g_gpu_device)
    Host::AddOSDMessage(std::string(message), Host::OSD_CRITICAL_ERROR_DURATION);
}

bool SwitchNoGUIPlatform::ConfirmMessage(const std::string_view& title, const std::string_view& message)
{
  return true;
}

void SwitchNoGUIPlatform::SetDefaultConfig(SettingsInterface& si)
{
}

bool SwitchNoGUIPlatform::CreatePlatformWindow(std::string title)
{
  // Mesa takes the surface size from the native window.
  const std::optional<WindowInfo> wi = GetPlatformWindowInfo();
  if (wi.has_value())
    nwindowSetDimensions(nwindowGetDefault(), wi->surface_width, wi->surface_height);

  return true;
}

bool SwitchNoGUIPlatform::HasPlatformWindow() const
{
  return true;
}

void SwitchNoGUIPlatform::DestroyPlatformWindow()
{
}

std::optional<WindowInfo> SwitchNoGUIPlatform::GetPlatformWindowInfo()
{
  WindowInfo wi;
  AppletOperationMode mode = appletGetOperationMode();
  if (mode == AppletOperationMode_Handheld)
  {
    wi.surface_width = 1280;
    wi.surface_height = 720;
  }
  else
  {
    wi.surface_width = 1920;
    wi.surface_height = 1080;
  }
  wi.surface_scale = 1.2f;
  wi.surface_refresh_rate = 60.f;
  wi.surface_format = GPUTexture::Format::RGBA8;
  wi.type = WindowInfo::Type::Switch;
  wi.window_handle = nwindowGetDefault();
  return wi;
}

void SwitchNoGUIPlatform::SetPlatformWindowTitle(std::string title)
{
}

std::optional<u32> SwitchNoGUIPlatform::ConvertHostKeyboardStringToCode(const std::string_view& str)
{
  return std::nullopt;
}

std::optional<std::string> SwitchNoGUIPlatform::ConvertHostKeyboardCodeToString(u32 code)
{
  return std::nullopt;
}

void SwitchNoGUIPlatform::RunMessageLoop()
{
  while (m_message_loop_running.load(std::memory_order_acquire))
  {
    if (!appletMainLoop())
      NoGUIHost::StopRunning();

    // Do not spin a whole core, callbacks posted by the CPU thread are not latency critical.
    svcSleepThread(2'000'000);

    std::unique_lock lock(m_callback_queue_mutex);
    while (!m_callback_queue.empty())
    {
      std::function<void()> func = std::move(m_callback_queue.front());
      m_callback_queue.pop_front();
      lock.unlock();
      func();
      lock.lock();
    }
  }
}

void SwitchNoGUIPlatform::ExecuteInMessageLoop(std::function<void()> func)
{
  std::unique_lock lock(m_callback_queue_mutex);
  m_callback_queue.push_back(std::move(func));
}

void SwitchNoGUIPlatform::QuitMessageLoop()
{
  m_message_loop_running.store(false, std::memory_order_release);
}

void SwitchNoGUIPlatform::SetFullscreen(bool enabled)
{
}

bool SwitchNoGUIPlatform::RequestRenderWindowSize(s32 new_window_width, s32 new_window_height)
{
  return false;
}

bool SwitchNoGUIPlatform::OpenURL(const std::string_view& url)
{
  return false;
}

bool SwitchNoGUIPlatform::CopyTextToClipboard(const std::string_view& text)
{
  return false;
}
