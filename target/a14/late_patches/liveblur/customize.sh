#!/usr/bin/env bash

QPRUNE_SMALI=""
for dir in "$APKTOOL_DIR/system_ext/priv-app/SystemUI/SystemUI.apk"/smali*; do
    if [ -f "$dir/com/android/systemui/QpRune.smali" ]; then
        QPRUNE_SMALI="$dir/com/android/systemui/QpRune.smali"
        break
    fi
done

if [ -z "$QPRUNE_SMALI" ]; then
    for dir in "$APKTOOL_DIR/system/priv-app/SystemUI/SystemUI.apk"/smali*; do
        if [ -f "$dir/com/android/systemui/QpRune.smali" ]; then
            QPRUNE_SMALI="$dir/com/android/systemui/QpRune.smali"
            break
        fi
    done
fi

if [ -f "$QPRUNE_SMALI" ]; then
    LOG "- Custom patching QpRune.smali for Captured Blur at: $QPRUNE_SMALI"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

pattern1 = r"(sput-boolean\s+(v\d+),\s+Lcom/android/systemui/QpRune;->QUICK_PANEL_BLUR_DEFAULT:Z)"
def rep1(m):
    return f"const/4 {m.group(2)}, 0x0\n    {m.group(1)}"

pattern2 = r"(sput-boolean\s+(v\d+),\s+Lcom/android/systemui/QpRune;->QUICK_PANEL_BLUR_MASSIVE:Z)"
def rep2(m):
    return f"const/4 {m.group(2)}, 0x1\n    {m.group(1)}"

new_content, count1 = re.subn(pattern1, rep1, content)
new_content, count2 = re.subn(pattern2, rep2, new_content)

if count1 > 0 and count2 > 0:
    with open(file_path, "w") as f:
        f.write(new_content)
    print(f"Successfully patched QpRune.smali (Live Blur Disabled, Captured Blur Forced)")
else:
    print("Warning: QpRune.smali blur pattern not found or already patched!")
' "$QPRUNE_SMALI"
else
    LOGW "QpRune.smali not found in SystemUI.apk"
fi
