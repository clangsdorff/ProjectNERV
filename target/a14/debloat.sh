#
# Copyright (C) 2025 BasGame1
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Debloat list for the Exynos 850 platform, using Exynos 990 platform files
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry (eg. "/system/dpolicy_system")
# - DO NOT add a slash at the start of any entry (eg. "/dpolicy_system")

# Camera SDK
SYSTEM_DEBLOAT+="
system/etc/default-permissions/default-permissions-com.samsung.android.globalpostprocmgr.xml
system/etc/default-permissions/default-permissions-com.samsung.petservice.xml
system/etc/default-permissions/default-permissions-com.samsung.videoscan.xml
system/etc/default-permissions/default-permissions-com.sec.factory.cameralyzer.xml
system/etc/permissions/cameraservice.xml
system/etc/permissions/privapp-permissions-com.samsung.android.globalpostprocmgr.xml
system/etc/permissions/privapp-permissions-com.samsung.petservice.xml
system/etc/permissions/privapp-permissions-com.samsung.videoscan.xml
system/etc/permissions/sec_camerax_impl.xml
system/etc/permissions/sec_camerax_service.xml
system/framework/sec_camerax_impl.jar
system/framework/scamera_sep.jar
system/priv-app/GlobalPostProcMgr
system/priv-app/PetService
system/priv-app/SCameraSDKService
system/priv-app/sec_camerax_service
system/priv-app/VideoScan
system/etc/permissions/privapp-permissions-com.samsung.ipservice.xml
system/priv-app/IPService
system/priv-app/DeviceQualityAgent35
system/priv-app/SMT
system/priv-app/SamsungSmartSuggestions
system/priv-app/MediaSearch
system/app/BixbyRoutines
system/priv-app/BixbyRoutines
system/priv-app/McfServer
system/priv-app/Mcfds
system/priv-app/BeaconManager
system/priv-app/SecSdhms
system/priv-app/KnoxCore
system/app/KnoxAttestationAgent
system/priv-app/KLMSAgent
system/app/UniversalMDMClient
system/app/TEEgrisTuiService
system/bin/insthk
system/etc/init/insthk_teegris.rc
system/etc/sysconfig/preinstalled-packages-com.samsung.sec.android.teegris.tui_service.xml
system/priv-app/CMHProvider
system/priv-app/RubinVersion36
system/etc/default-permissions/default-permissions-com.samsung.android.rubin.app.xml
system/etc/permissions/privapp-permissions-com.samsung.android.rubin.app.xml
system/etc/permissions/signature-permissions-com.samsung.android.rubin.app.xml
"

# Wi-Fi Hotspot Overlays
PRODUCT_DEBLOAT+="
overlay/SoftapOverlayDualAp
overlay/SoftapOverlayOWE
"

# StorageShare (kSMBd)
SYSTEM_DEBLOAT+="
system/etc/default-permissions/default-permissions-com.samsung.android.hwresourceshare.storage.xml
system/etc/init/ksmbd.rc
system/etc/permissions/privapp-permissions-com.samsung.android.hwresourceshare.storage.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.hwresourceshare.storage.xml
system/etc/ksmbd.conf
system/priv-app/StorageShare
"
