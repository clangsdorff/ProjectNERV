LOG "-Installing China Smart Manager"

# Delete old SmartManager packages
DELETE_FROM_WORK_DIR "system" "system/app/SmartManager_v6_DeviceSecurity"
DELETE_FROM_WORK_DIR "system" "system/priv-app/SmartManager_v5"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/app/SmartManager_v6_DeviceSecurity_CN" 0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/priv-app/SmartManagerCN" 0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/priv-app/SAppLock" 0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/priv-app/Firewall" 0 0 755 "u:object_r:system_file:s0"

DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.lool.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/signature-permissions-com.samsung.android.lool.xml"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/etc/permissions/privapp-permissions-com.samsung.android.sm_cn.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/etc/permissions/signature-permissions-com.samsung.android.sm_cn.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SRC_DIR/target/a14/patches/smartmanager_cn/files" "system" "system/etc/permissions/privapp-permissions-com.sec.android.app.firewall.xml" 0 0 644 "u:object_r:system_file:s0"

# Fix SELinux contexts for files that don't have entries in plat_file_contexts
echo "/system/app/SmartManager_v6_DeviceSecurity_CN/SmartManager_v6_DeviceSecurity_CN\\.apk u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
echo "/system/priv-app/SmartManagerCN/SmartManagerCN\\.apk u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
echo "/system/priv-app/SAppLock/SAppLock\\.apk u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
echo "/system/priv-app/Firewall/Firewall\\.apk u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"

# Fix floating feature package name
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SMARTMANAGER_CONFIG_PACKAGE_NAME" "com.samsung.android.sm_cn"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SECURITY_CONFIG_DEVICEMONITOR_PACKAGE_NAME" "com.samsung.android.sm.devicesecurity.tcm"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_SUPPORT_NAL_PRELOADAPP_REGULATION" "TRUE"
