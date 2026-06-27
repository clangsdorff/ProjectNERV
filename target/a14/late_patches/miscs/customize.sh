LOG "-Patch CPU governor"
sed -i \
    's|scaling_governor energy_aware|scaling_governor schedutil|g' \
    "$WORK_DIR/vendor/etc/init/init.s5e3830.rc"

LOG "-Fixing Mali EGL property SELinux label for wide gamut support"
echo -e "\nro.vendor.arm.egl.configs. u:object_r:graphics_config_prop:s0 prefix" >> "$WORK_DIR/system/system/etc/selinux/plat_property_contexts"

LOG "-Patching task_profiles.json to fix GpisSfCpuset root cpuset write error"
for file in "$WORK_DIR/system/system/etc/task_profiles.json" "$WORK_DIR/system_ext/etc/task_profiles.json" "$WORK_DIR/system/system_ext/etc/task_profiles.json" "$WORK_DIR/system/system/system_ext/etc/task_profiles.json"; do
    if [ -f "$file" ]; then
        LOG "  Patching task_profiles in $file"
        python3 -c "
import json, sys
file = sys.argv[1]
with open(file, 'r') as f:
    data = json.load(f)
modified = False
for attr in data.get('Attributes', []):
    if attr.get('Name') == 'GpisSfCpuset' and attr.get('File') == 'cpus':
        attr['File'] = 'top-app/cpus'
        modified = True
if modified:
    with open(file, 'w') as f:
        json.dump(data, f, indent=2)
" "$file" || true
    fi
done

LOG "-Injecting Deep I/O and Kernel Scheduler Tweaks into init"
cat << 'EOF' >> "$WORK_DIR/vendor/etc/init/init.s5e3830.rc"

on property:sys.boot_completed=1
    # Delay AOD settings write to avoid SettingsProvider race condition at boot
    setprop nerv.aod.pending 1

on property:nerv.aod.pending=1
    exec - system system -- /system/bin/settings put secure doze_always_on 1
    exec - system system -- /system/bin/settings put secure screensaver_enabled 0
    exec - system system -- /system/bin/settings put secure screensaver_activate_on_sleep 0
    setprop nerv.aod.pending 0

    # Advanced I/O Tweaks for eMMC bottleneck
    write /sys/block/mmcblk0/queue/read_ahead_kb 2048
    write /sys/block/mmcblk0/queue/scheduler "mq-deadline"
    write /sys/block/mmcblk0/queue/nr_requests 128
    write /sys/block/mmcblk0/queue/iostats 0
    # Disable ZRAM readahead to save CPU
    write /sys/block/zram0/queue/read_ahead_kb 0

    # Disable Kernel FSync to eliminate I/O wait on SQLite writes
    write /sys/module/sync/parameters/fsync_enabled N
    
    # Push dirty pages to RAM instead of disk to prevent eMMC stalls
    write /proc/sys/vm/swappiness 30
    write /proc/sys/vm/vfs_cache_pressure 30
    write /proc/sys/vm/dirty_ratio 80
    write /proc/sys/vm/dirty_background_ratio 40
EOF

LOG "-Fix Chrome crash: export libbinder_ndk.so to public namespace"
_PL_FILE="$WORK_DIR/system/system/etc/public.libraries.txt"
if [ -f "$_PL_FILE" ]; then
    if ! grep -q "libbinder_ndk.so" "$_PL_FILE"; then
        echo "libbinder_ndk.so" >> "$_PL_FILE"
        LOG "- Added libbinder_ndk.so to public.libraries.txt"
    else
        LOG "- libbinder_ndk.so already present in public.libraries.txt"
    fi
else
    LOG "- public.libraries.txt not found, creating and adding libbinder_ndk.so"
    mkdir -p "$(dirname "$_PL_FILE")"
    echo "libbinder_ndk.so" > "$_PL_FILE"
fi
unset _PL_FILE
