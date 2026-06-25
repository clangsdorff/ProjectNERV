#!/usr/bin/env bash

# Find SecContentProvider in services.jar
SECCONTENT_SMALI=""
for dir in "$APKTOOL_DIR/system/framework/services.jar"/smali*; do
    if [ -f "$dir/com/android/server/enterprise/content/SecContentProvider.smali" ]; then
        SECCONTENT_SMALI="$dir/com/android/server/enterprise/content/SecContentProvider.smali"
        break
    fi
done

if [ -f "$SECCONTENT_SMALI" ]; then
    LOG "- Custom patching SecContentProvider.smali for MDM Bypass at: $SECCONTENT_SMALI"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

pattern = r"(\.method public query\(Landroid/net/Uri;.*?\)Landroid/database/Cursor;).*?(\.end method)"

def count_registers(sig):
    m = re.search(r"\((.*?)\)", sig)
    if not m:
        return 8
    params = m.group(1)
    count = 1  # p0 = this (non-static)
    i = 0
    while i < len(params):
        c = params[i]
        if c == "[":
            i += 1  # array modifier, skip
        elif c == "L":
            end = params.index(";", i)
            i = end + 1
            count += 1
        elif c in "BCDFIJSZ":
            count += 1
            i += 1
        else:
            i += 1
    return count + 1  # +1 for v0 local (null return)

def repl(m):
    regs = count_registers(m.group(1))
    return f"{m.group(1)}\n    .registers {regs}\n    const/4 v0, 0x0\n    return-object v0\n{m.group(2)}"

new_content, count = re.subn(pattern, repl, content, flags=re.DOTALL)

if count > 0:
    with open(file_path, "w") as f:
        f.write(new_content)
    print(f"Successfully patched SecContentProvider.smali ({count} method(s) nuked — returns null instantly for all Knox MDM queries)")
else:
    print("Warning: query method not found in SecContentProvider.smali!")
' "$SECCONTENT_SMALI"
else
    LOGW "SecContentProvider.smali not found in services.jar"
fi

# Find SecContentProvider2 in services.jar
SECCONTENT2_SMALI=""
for dir in "$APKTOOL_DIR/system/framework/services.jar"/smali*; do
    if [ -f "$dir/com/android/server/enterprise/content/SecContentProvider2.smali" ]; then
        SECCONTENT2_SMALI="$dir/com/android/server/enterprise/content/SecContentProvider2.smali"
        break
    fi
done

if [ -f "$SECCONTENT2_SMALI" ]; then
    LOG "- Custom patching SecContentProvider2.smali for MDM Bypass at: $SECCONTENT2_SMALI"
    python3 -c '
import re
import sys

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

pattern = r"(\.method public query\(Landroid/net/Uri;.*?\)Landroid/database/Cursor;).*?(\.end method)"

def count_registers(sig):
    m = re.search(r"\((.*?)\)", sig)
    if not m:
        return 8
    params = m.group(1)
    count = 1  # p0 = this (non-static)
    i = 0
    while i < len(params):
        c = params[i]
        if c == "[":
            i += 1
        elif c == "L":
            end = params.index(";", i)
            i = end + 1
            count += 1
        elif c in "BCDFIJSZ":
            count += 1
            i += 1
        else:
            i += 1
    return count + 1  # +1 for v0 local (null return)

def repl(m):
    regs = count_registers(m.group(1))
    return f"{m.group(1)}\n    .registers {regs}\n    const/4 v0, 0x0\n    return-object v0\n{m.group(2)}"

new_content, count = re.subn(pattern, repl, content, flags=re.DOTALL)

if count > 0:
    with open(file_path, "w") as f:
        f.write(new_content)
    print(f"Successfully patched SecContentProvider2.smali ({count} method(s) nuked)")
else:
    print("Warning: query method not found in SecContentProvider2.smali!")
' "$SECCONTENT2_SMALI"
else
    LOGW "SecContentProvider2.smali not found in services.jar (non-fatal)"
fi
