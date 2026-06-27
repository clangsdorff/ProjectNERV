#!/usr/bin/env bash

# AOD Wandering Range Fix (LCD)
# On OLED the display blanks during the lockscreen→AOD transition, so the burn-in
# protection wandering offset is applied invisibly. On LCD (our forced MODE_NORMAL fix)
# the screen stays on, so the wandering offset is applied as a visible slide animation.
#
# SEC_FLOATING_FEATURE_LCD_CONFIG_AOD_FULLSCREEN is 0 on A14 (not present in feature XML),
# so R51.V() returns false, selecting oversized wandering Rects in DN.smali:
#   PortClock:      Rect(-68, 0, 68, 712)       → visible 712px vertical slide
#   PortBattery:    Rect(-96, -16, 40, 120)      → visible slide
#   PortBottom:     Rect(-60, -40, 60, 80)       → visible slide
#   ExtraClock:     Rect(-484, -60, 484, 0)      → visible 968px horizontal slide (non-fold path)
#   PortNowBar:     Rect(-140, -60, 140, 60)     → always large (no R51.V() check)
#
# Fix: force the R51.V()=true (small-range) code paths for PortClock, PortBattery,
# PortBottom, ExtraClock by removing the if-eqz branch. Zero out PortNowBar's range
# since LCD panels have no OLED burn-in risk.
#
# Matching strategy: label names (cond_NNN) differ between APK versions, so we match
# each if-eqz by the true-path content that immediately follows it (first instruction
# or constant load that is unique to that branch).

DECODE_APK "system" "system/priv-app/AODService_v80/AODService_v80.apk"

AOD_APK_DIR=""
for dir in "$APKTOOL_DIR/system/priv-app/AODService_v80/AODService_v80.apk"/smali*; do
    if [ -f "$dir/aod/DN.smali" ]; then
        AOD_APK_DIR="$dir"
        break
    fi
done

if [ -n "$AOD_APK_DIR" ]; then
    DN_SMALI="$AOD_APK_DIR/aod/DN.smali"
    LOG "- Patching AOD wandering ranges for LCD at: $DN_SMALI"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

original = content
patches_applied = 0


def remove_if_eqz_before(content, true_path_anchor):
    """Remove the if-eqz v0, :cond_X line that immediately precedes true_path_anchor."""
    pattern = r"\n    if-eqz v0, :cond_\w+\n(" + re.escape(true_path_anchor) + ")"
    m = re.search(pattern, content)
    if m:
        replaced = content[:m.start()] + "\n" + m.group(1) + content[m.end():]
        return replaced, True
    return content, False


# PortClock: true-path Rect(-32, 0, 32, 120) — false-path Rect(-68, 0, 68, 712)
# Identified by const/16 v2, 0x78 immediately after new-instance
content, ok = remove_if_eqz_before(
    content,
    "\n    new-instance v0, Landroid/graphics/Rect;\n\n    const/16 v2, 0x78\n"
)
if ok:
    patches_applied += 1
    print("PortClock: removed if-eqz — uses Rect(-32, 0, 32, 120) instead of Rect(-68, 0, 68, 712)")
else:
    print("Warning: PortClock pattern not found — already patched or APK changed")

# PortBattery: true-path Rect(-88, 0, 0, 8) — false-path Rect(-96, -16, 40, 120)
# Identified by const/16 v2, -0x58 immediately after new-instance
content, ok = remove_if_eqz_before(
    content,
    "\n    new-instance v0, Landroid/graphics/Rect;\n\n    const/16 v2, -0x58\n"
)
if ok:
    patches_applied += 1
    print("PortBattery: removed if-eqz — uses Rect(-88, 0, 0, 8) instead of Rect(-96, -16, 40, 120)")
else:
    print("Warning: PortBattery pattern not found — already patched or APK changed")

# PortBottom: true-path Rect(-40, 0, 40, 8) via {v0, v2, v1, v15, v13}
# false-path Rect(-60, -40, 60, 80)
content, ok = remove_if_eqz_before(
    content,
    "\n    new-instance v0, Landroid/graphics/Rect;\n\n    invoke-direct {v0, v2, v1, v15, v13}, Landroid/graphics/Rect;-><init>(IIII)V\n"
)
if ok:
    patches_applied += 1
    print("PortBottom: removed if-eqz — uses Rect(-40, 0, 40, 8) instead of Rect(-60, -40, 60, 80)")
else:
    print("Warning: PortBottom pattern not found — already patched or APK changed")

# ExtraClock: true-path Rect(-60, -32, 60, 32) via {v0, v12, v6, v11, v7}
# false-path on non-fold A14: Rect(-484, -60, 484, 0) — 968px horizontal range
content, ok = remove_if_eqz_before(
    content,
    "\n    new-instance v0, Landroid/graphics/Rect;\n\n    invoke-direct {v0, v12, v6, v11, v7}, Landroid/graphics/Rect;-><init>(IIII)V\n"
)
if ok:
    patches_applied += 1
    print("ExtraClock: removed if-eqz — uses Rect(-60, -32, 60, 32) instead of Rect(-484, -60, 484, 0)")
else:
    print("Warning: ExtraClock pattern not found — already patched or APK changed")

# PortNowBar: zero out Rect(-140, -60, 140, 60) — LCD has no OLED burn-in risk
nowbar_invoke = "    invoke-direct {v0, v3, v12, v4, v11}, Landroid/graphics/Rect;-><init>(IIII)V"
nowbar_replacement = (
    "    const/4 v3, 0x0\n\n"
    "    const/4 v12, 0x0\n\n"
    "    const/4 v4, 0x0\n\n"
    "    const/4 v11, 0x0\n\n"
    "    invoke-direct {v0, v3, v12, v4, v11}, Landroid/graphics/Rect;-><init>(IIII)V"
)
if nowbar_invoke in content and "const/4 v3, 0x0" not in content:
    content = content.replace(nowbar_invoke, nowbar_replacement, 1)
    patches_applied += 1
    print("PortNowBar: zeroed wandering range Rect(-140, -60, 140, 60) -> Rect(0, 0, 0, 0)")
elif "const/4 v3, 0x0" in content:
    print("PortNowBar: already zeroed — skipping")
else:
    print("Warning: PortNowBar invoke-direct not found — already patched or APK changed")

if patches_applied > 0:
    with open(file_path, "w") as f:
        f.write(content)
    print(f"Successfully applied {patches_applied}/5 AOD wandering range patches to DN.smali")
elif content == original:
    print("No changes made to DN.smali")
' "$DN_SMALI"
else
    LOGW "AODService_v80 DN.smali not found in decoded APK — skipping AOD wandering fix"
fi
