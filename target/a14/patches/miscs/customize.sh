LOG "-Enable Vulkan"
SET_PROP "vendor" "ro.hwui.use_vulkan" "false"
SET_PROP "vendor" "debug.hwui.use_hint_manager" "true"

LOG "-Disable A2DP Offload"
SET_PROP "vendor" "persist.bluetooth.a2dp_offload.disabled" "true"
SET_PROP "vendor" "ro.bluetooth.a2dp_offload.supported" "false"
SET_PROP "system" "persist.bluetooth.samsung.a2dp_offload.cap" "none"

LOG "-Patch CPU governor"
sed -i \
    's|scaling_governor energy_aware|scaling_governor schedutil|g' \
    "$WORK_DIR/vendor/etc/init/init.s5e3830.rc"

LOG "-Replacing fstab with prebuilt"
DELETE_FROM_WORK_DIR "vendor" "etc/fstab.s5e3830"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/miscs/files" "vendor" "etc/fstab.s5e3830" 0 0 644 "u:object_r:vendor_configs_file:s0"

LOG "-Fixing Mali EGL property SELinux label for wide gamut support"
echo -e "\nro.vendor.arm.egl.configs. u:object_r:graphics_config_prop:s0 prefix" >> "$WORK_DIR/system/system/etc/selinux/plat_property_contexts"

LOG "-Optimize Memory (Chimera LMK) using Stock A14 configuration"
SET_PROP "system" "ro.slmk.dha_empty_min" "4"
SET_PROP "system" "ro.slmk.dha_empty_max" "16"
SET_PROP "system" "ro.slmk.2nd.dha_empty_max" "30"
SET_PROP "system" "ro.slmk.psi_critical" "150"
SET_PROP "system" "ro.slmk.freelimit_val" "14"
SET_PROP "system" "ro.slmk.swap_free_low_percentage" "25"
SET_PROP "system" "ro.slmk.2nd.swap_free_low_percentage" "35"
SET_PROP "system" "ro.slmk.chimera_strategy_4gb" "900,8,8,1406"
SET_PROP "system" "ro.sys.fw.bg_apps_limit" "32"

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

LOG "-Allow system_server to write to cgroup v1 files (needed for legacy kernels mounting cpuset as v1)"
ADD_SELINUX_ENTRY "system" "system/etc/selinux/plat_sepolicy.cil" "(allow system_server cgroup (file (write)))"

LOG "-Forcing DMA-BUF heaps for software Codec2 to prevent VP9 decoder crash"
SET_PROP "system" "debug.c2.use_dmabufheaps" "1"

LOG "-Disable background blurs to prevent GPU compositor lag and UI stutters on Mali-G52"
SET_PROP "system" "ro.surface_flinger.supports_background_blur" "0"
SET_PROP "system" "ro.sf.blurs_are_expensive" "1"
SET_PROP "system" "persist.sys.sf.disable_blurs" "1"

LOG "-Disable Wide Color Gamut and HDR to prevent EGL config mismatch stutters on A14 LCD panel"
SET_PROP "system" "ro.surface_flinger.has_wide_color_display" "false"
SET_PROP "system" "ro.surface_flinger.has_HDR_display" "false"
SET_PROP "system" "persist.sys.sf.color_saturation" "1.0"
SET_PROP "system" "persist.sys.sf.native_mode" "0"

LOG "-Disable DymLock (Dynamic Lockscreen plugin system) to prevent 11s SystemUI freeze on boot"
SET_PROP "system" "ro.lockscreen.dls_enabled" "false"
SET_PROP "system" "persist.sys.dls_enabled" "0"

LOG "-Force GSM-only telephony to prevent CDMA init ANR on SM-A145F/TUR (GSM-only device)"
SET_PROP "system" "ro.telephony.default_network" "9"

LOG "-Enable AOD always-on doze mode"
SET_PROP "system" "ro.doze.always_on" "true"

LOG "-Advanced UI/HWUI Caching and Rendering Optimizations"
SET_PROP "system" "ro.hwui.texture_cache_size" "72"
SET_PROP "system" "ro.hwui.layer_cache_size" "48"
SET_PROP "system" "ro.hwui.r_buffer_cache_size" "8"
SET_PROP "system" "ro.hwui.path_cache_size" "32"
SET_PROP "system" "ro.hwui.gradient_cache_size" "1"
SET_PROP "system" "ro.hwui.drop_shadow_cache_size" "6"
SET_PROP "system" "ro.hwui.texture_cache_flushrate" "0.4"
SET_PROP "system" "ro.hwui.text_small_cache_width" "1024"
SET_PROP "system" "ro.hwui.text_small_cache_height" "1024"
SET_PROP "system" "ro.hwui.text_large_cache_width" "2048"
SET_PROP "system" "ro.hwui.text_large_cache_height" "2048"
SET_PROP "system" "debug.sf.enable_gl_backpressure" "0"
SET_PROP "system" "debug.sf.hw" "0"
SET_PROP "system" "debug.sf.latch_unsignaled" "0"
SET_PROP "system" "ro.surface_flinger.max_frame_buffer_acquired_buffers" "2"

LOG "-Dalvik VM Advanced GC & DexOpt Tuning to prevent freezes"
SET_PROP "system" "dalvik.vm.heapminfree" "8m"
SET_PROP "system" "dalvik.vm.heapmaxfree" "32m"
SET_PROP "system" "dalvik.vm.heaptargetutilization" "0.75"

# Force native compilation during Boot Animation (User explicitly requested this)
SET_PROP "system" "pm.dexopt.first-boot" "speed-profile"
SET_PROP "system" "pm.dexopt.boot" "speed-profile"
SET_PROP "system" "pm.dexopt.shared" "speed"
SET_PROP "system" "pm.dexopt.bg-dexopt" "speed-profile"

LOG "-Injecting Deep I/O and Kernel Scheduler Tweaks into init"
cat << 'EOF' >> "$WORK_DIR/vendor/etc/init/init.s5e3830.rc"

on property:sys.boot_completed=1
    # Delay AOD settings write to avoid SettingsProvider race condition at boot
    setprop nerv.aod.pending 1

on property:nerv.aod.pending=1
    exec - system system -- /system/bin/settings put secure doze_always_on 1
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

LOG "-Injecting Native SysConfig Component Override to prevent boot-time Keystore ANRs"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/miscs/files" "system" "system/etc/sysconfig/smartsuggestions_override.xml" 0 0 644 "u:object_r:system_file:s0"



LOG "-Disable Thermal Throttling, SDHMS, and Knox via Props"
SET_PROP "system" "ro.config.knox" "0"
SET_PROP "system" "ro.config.tima" "0"
SET_PROP "system" "ro.hw.fps" "true"
SET_PROP "system" "sys.siop.level" "0"
SET_PROP "system" "ro.thermal_throttle_enable" "false"

LOG "-Fix: Disable Samsung SEC_SF_EFFECTS blur override"
SET_PROP "system" "persist.sys.sec_sf_effects.disable" "1"
SET_PROP "vendor" "persist.sys.sec_sf_effects.disable" "1"
SET_PROP "system" "debug.sec_sf_effects.disable" "1"

LOG "-Fix: Disable duplicate wallpaper render on screen wake"
SET_PROP "system" "ro.lockscreen.wallpaper.separate" "false"
SET_PROP "system" "persist.wm.debug.wallpaper_anim" "0"

LOG "-Fix: Disable SGM FgCheckThread screen-on timeout"
SET_PROP "system" "ro.gamemanager.sdhms.enable" "false"
SET_PROP "system" "persist.sys.game.mode.check" "0"


LOG "-Fix: Tune LMKD thresholds"
SET_PROP "system" "ro.slmk.psi_critical" "200"
SET_PROP "system" "ro.slmk.swap_free_low_percentage" "20"
SET_PROP "system" "ro.slmk.2nd.swap_free_low_percentage" "30"

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
