#!/usr/bin/env bash

# LCD AOD Compatibility Fix (A14 / Exynos 850)
#
# Three-component patch for full AOD support on LCD panels:
#
#   [1] LocalDisplayAdapter — setDisplayState: DOZE(3) → MODE_NORMAL(2)
#       The A14 vendor display HAL blanks the LCD on DOZE(3). We intercept
#       DOZE(3) only and force MODE_NORMAL(2) so the LCD stays on during
#       active AOD. DOZE_SUSPEND(4) is intentionally NOT intercepted: Samsung's
#       blank path turns the LCD off, which is correct for tap-to-show standby.
#
#   [2] DisplayStateController — dozeScreenState: OFF(1) → DOZE_SUSPEND(4)
#       Samsung's AOD service sends dozeScreenState=OFF(1) during standby on
#       LCD (it cannot send DOZE_SUSPEND natively). We remap OFF(1)→DOZE_SUSPEND(4)
#       so the TSP HAL receives activate(DOZE_SUSPEND=4), enabling single-tap
#       detection. Component [1] lets DOZE_SUSPEND pass through, so the LCD
#       stays off during standby. Result: tap wakes AOD, DOZE(3) shows content.
#
#   [3] LightsService — setLightLocked: UnsupportedOperationException catch
#       A14's vendor lights HAL throws UnsupportedOperationException on DOZE
#       backlight calls. Without a catch this crashes PhotonicModulator, killing
#       DozeService and shutting AOD down. We add a silent catch block.

# ── Component 1: LocalDisplayAdapter ────────────────────────────────────────

LOCAL_DISPLAY_DEVICE_SMALI=""
for dir in "$APKTOOL_DIR/system/framework/services.jar"/smali*; do
    if [ -f "$dir/com/android/server/display/LocalDisplayAdapter\$LocalDisplayDevice\$1.smali" ]; then
        LOCAL_DISPLAY_DEVICE_SMALI="$dir/com/android/server/display/LocalDisplayAdapter\$LocalDisplayDevice\$1.smali"
        break
    fi
done

if [ -f "$LOCAL_DISPLAY_DEVICE_SMALI" ]; then
    LOG "- [lcd_aod_fix/1] Patching LocalDisplayAdapter setDisplayState for LCD AOD"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

method_m = re.search(
    r"\.method (?:(?:public|private|protected|static|final|synthetic)\s+)*setDisplayState\(I\)V",
    content
)
if not method_m:
    print("Warning: setDisplayState method not found — skipping component 1")
    sys.exit(0)

end_m = re.search(r"\.end method", content[method_m.end():])
if not end_m:
    print("Warning: .end method not found — skipping component 1")
    sys.exit(0)

method_start = method_m.start()
method_end_abs = method_m.end() + end_m.end()
method_body = content[method_start:method_end_abs]

if ":aod_tap_cont" in method_body:
    print("Already patched (fallback injection) — skipping component 1")
    sys.exit(0)

# Primary: remove if-eqz for DOZE(3) branch only, leave DOZE_SUSPEND(4) intact.
# In setDisplayState, DOZE_SUSPEND(4) dispatch appears before DOZE(3), so the
# 1st regex match is DOZE_SUSPEND and the 2nd is DOZE. Remove only the 2nd.
aod_flag_pattern = (
    r"(    sget-boolean v\d+, Lcom/android/server/power/PowerManagerUtil;"
    r"->SEC_FEATURE_AOD_LOOK_CHARGING_UI:Z\n)"
    r"\n?"
    r"    if-eqz v\d+, :\w+\n"
    r"\n?"
    r"(    goto :\w+\n)"
)

matches = list(re.finditer(aod_flag_pattern, method_body))
if len(matches) >= 2:
    m = matches[1]
    replacement = m.group(1) + m.group(2)
    new_body = method_body[:m.start()] + replacement + method_body[m.end():]
    new_content = content[:method_start] + new_body + content[method_end_abs:]
    with open(file_path, "w") as f:
        f.write(new_content)
    print("OK: removed SEC_FEATURE_AOD_LOOK_CHARGING_UI if-eqz for DOZE(3) — DOZE_SUSPEND(4) passes through")
    sys.exit(0)

if "SEC_FEATURE_AOD_LOOK_CHARGING_UI" in method_body and len(matches) <= 1:
    print("Already patched (DOZE if-eqz removed) — skipping component 1")
    sys.exit(0)

# Fallback: inject state check after move/from16 v1, p1
print(f"Note: primary pattern not found ({len(matches)} matches) — trying injection fallback")

regs_m = re.search(r"\.registers\s+(\d+)", method_body)
if not regs_m or int(regs_m.group(1)) < 3:
    print("Warning: insufficient registers — component 1 not applied")
    sys.exit(0)

copy_m = re.search(r"(    move/from16 v1, p1\n)", method_body) or \
         re.search(r"(    move v1, p1\n)", method_body)
if not copy_m:
    print("Warning: move v1, p1 not found — component 1 not applied")
    sys.exit(0)

injection = (
    "    const/4 v2, 0x3\n"
    "    if-ne v1, v2, :aod_tap_cont\n"
    "    const/4 v1, 0x2\n"
    "\n"
    "    :aod_tap_cont\n"
)
new_body = method_body[:copy_m.end()] + injection + method_body[copy_m.end():]
new_content = content[:method_start] + new_body + content[method_end_abs:]
with open(file_path, "w") as f:
    f.write(new_content)
print("OK: fallback injection — DOZE(3)→MODE_NORMAL, DOZE_SUSPEND(4) untouched")
' "$LOCAL_DISPLAY_DEVICE_SMALI"
else
    LOGW "LocalDisplayAdapter\$LocalDisplayDevice\$1.smali not found — skipping component 1"
fi

# ── Component 2: DisplayStateController ─────────────────────────────────────

DISPLAY_STATE_CONTROLLER_SMALI=""
for dir in "$APKTOOL_DIR/system/framework/services.jar"/smali*; do
    if [ -f "$dir/com/android/server/display/state/DisplayStateController.smali" ]; then
        DISPLAY_STATE_CONTROLLER_SMALI="$dir/com/android/server/display/state/DisplayStateController.smali"
        break
    fi
done

if [ -f "$DISPLAY_STATE_CONTROLLER_SMALI" ]; then
    LOG "- [lcd_aod_fix/2] Patching DisplayStateController OFF→DOZE_SUSPEND for TSP tap-to-show"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

if "if-ne v1, v2, :cond_tsp_cont" in content:
    print("Already patched — skipping component 2")
    sys.exit(0)

# Match the if-eqz v1 check immediately before dozeScreenStateReason iget.
# Label name varies between APK versions — match by surrounding context instead.
pattern = (
    r"(    if-eqz v1, :cond_\w+\n)"
    r"\n"
    r"(    iget v4, p1, Landroid/hardware/display/DisplayManagerInternal"
    r"\$DisplayPowerRequest;->dozeScreenStateReason:I)"
)
replacement = (
    r"\1"
    "\n"
    "    const/4 v2, 0x1\n"
    "\n"
    "    if-ne v1, v2, :cond_tsp_cont\n"
    "\n"
    "    const/4 v1, 0x4\n"
    "\n"
    "    :cond_tsp_cont\n"
    "\n"
    r"\2"
)

new_content, count = re.subn(pattern, replacement, content, count=1)
if count == 0:
    print("Warning: target pattern not found in DisplayStateController.smali — component 2 not applied")
    sys.exit(0)

with open(file_path, "w") as f:
    f.write(new_content)
print("OK: dozeScreenState=OFF(1) now maps to DOZE_SUSPEND(4) for TSP single-tap detection")
' "$DISPLAY_STATE_CONTROLLER_SMALI"
else
    LOGW "DisplayStateController.smali not found — skipping component 2"
fi

# ── Component 3: LightsService ───────────────────────────────────────────────

LIGHTS_SMALI=""
for dir in "$APKTOOL_DIR/system/framework/services.jar"/smali*; do
    if [ -f "$dir/com/android/server/lights/LightsService\$LightImpl.smali" ]; then
        LIGHTS_SMALI="$dir/com/android/server/lights/LightsService\$LightImpl.smali"
        break
    fi
done

if [ -f "$LIGHTS_SMALI" ]; then
    LOG "- [lcd_aod_fix/3] Patching LightsService UnsupportedOperationException catch"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

if "catch_unsupported_lights" in content:
    print("Already patched — skipping component 3")
    sys.exit(0)

pattern = r"(\.catch Landroid/os/RemoteException; \{:try_start_\w+ \.\. :try_end_\w+\} :\w+)"

def inject_catch(m):
    original = m.group(1)
    range_match = re.search(r"(\{:try_start_\w+ \.\. :try_end_\w+\})", original)
    if not range_match:
        return original
    return (
        f"{original}\n"
        f"    .catch Ljava/lang/UnsupportedOperationException; "
        f"{range_match.group(1)} :catch_unsupported_lights"
    )

method_pattern = r"(\.method (?:(?:public|private|protected|static|final|synthetic)\s+)*setLightLocked\(.*?\)V.*?\.end method)"
def patch_method(mm):
    body = mm.group(1)
    if "catch_unsupported_lights" in body:
        return body
    patched, count = re.subn(pattern, inject_catch, body)
    if count > 0:
        patched = patched.replace(
            ".end method",
            "    :catch_unsupported_lights\n"
            "    move-exception v0\n"
            "    return-void\n"
            ".end method"
        )
    return patched

new_content, cnt = re.subn(method_pattern, patch_method, content, flags=re.DOTALL)
if cnt > 0 and "catch_unsupported_lights" in new_content:
    with open(file_path, "w") as f:
        f.write(new_content)
    print("OK: UnsupportedOperationException catch added to setLightLocked")
else:
    print("Warning: setLightLocked pattern not found — component 3 not applied")
' "$LIGHTS_SMALI"
else
    LOGW "LightsService\$LightImpl.smali not found — skipping component 3"
fi
