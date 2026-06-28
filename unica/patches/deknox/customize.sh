#!/bin/bash

# ==========================================================
# Project NERV - DeKnox & System Optimization Script
# Alvo: Galaxy A52s 5G (a52sxq)
# ==========================================================

# --- FUNÇÕES DE COMPATIBILIDADE (NÃO REMOVER) ---
# Estas funções garantem que o script funcione mesmo se as globais falharem

SET_FLOATING_FEATURE_CONFIG() {
    local feature=$1
    local action=$2
    local value=$3
    local file="work/vendor/etc/floating_feature.xml"
    if [ -f "$file" ]; then
        if [ "$action" == "--delete" ]; then
            sed -i "/$feature/d" "$file"
        else
            sed -i "s|<$feature>.*</$feature>|<$feature>$value</$feature>|g" "$file"
        fi
    fi
}

DELETE_FROM_WORK_DIR() {
    local partition=$1
    local path=$2
    local target="work/$partition/$path"
    [ -e "$target" ] && rm -rf "$target"
}

ADD_TO_WORK_DIR() {
    echo "[i] ADD_TO_WORK_DIR: $1"
}

# --- INÍCIO DA CUSTOMIZAÇÃO ---

# 1. Limpeza de Bloatware e Knox
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_BLOCKCHAIN_SERVICE" --delete

if [ "$TARGET_SINGLE_SYSTEM_IMAGE" == "qssi" ]; then
    ADD_TO_WORK_DIR "a05snsdxx" "system" "."
elif [ "$TARGET_SINGLE_SYSTEM_IMAGE" == "essi" ]; then
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/bin" 0 2000 751 "u:object_r:system_file:s0"
fi

# 2. SEÇÃO DEKNOX (REMOÇÃO)
KNOX_LIST=(
    "system/app/BlockchainBasicKit"
    "system/bin/dualdard"
    "system/bin/sem_daemon"
    "system/etc/init/dualdard.rc"
    "system/priv-app/HdmApk"
    "system/priv-app/KPECore"
    "system/priv-app/KnoxCore"
    "system/priv-app/KnoxERAgent"
    "system/priv-app/KnoxFrameBufferProvider"
    "system/priv-app/KnoxGuard"
    "system/priv-app/KnoxMposAgent"
    "system/priv-app/KnoxNetworkFilter"
    "system/priv-app/KnoxNeuralNetworkRuntime"
    "system/priv-app/KnoxPushManager"
    "system/priv-app/KnoxSandbox"
    "system/priv-app/KnoxZtFramework"
    "system/priv-app/SEMFactoryApp"
    "system/priv-app/knoxanalyticsagent"
    "system/priv-app/knoxvpnproxyhandler"
)

for item in "${KNOX_LIST[@]}"; do
    DELETE_FROM_WORK_DIR "system" "$item"
done

# Bibliotecas do Knox
for libdir in "lib" "lib64"; do
    for lib in libdualdar.so libepm.so libpersona.so libsec_sem.so libsec_semRil.so libsec_semTlc.so libtlc_payment_spay.so; do
        DELETE_FROM_WORK_DIR "system" "system/$libdir/$lib"
    done
done

# 3. PATCHES DE BYPASS (SMALI)
echo "==== Aplicando patches dinâmicos ===="
SMALI_FILES=$(find . -type f \( -name "*Policy.smali" -o -name "*Manager.smali" \) 2>/dev/null | grep -E "Knox|DualDAR|Hdm")

for file in $SMALI_FILES; do
    echo "[+] Patching: $file"
    # Força retorno falso/nulo em checagens do Knox
    sed -i 's/isKnoxEnabled()Z/isKnoxEnabled()Z\n    const\/4 v0, 0x0\n    return v0/g' "$file"
    sed -i 's/getKnoxVersion()Ljava\/lang\/String;/getKnoxVersion()Ljava\/lang\/String;\n    const\/4 v0, 0x0\n    return-object v0/g' "$file"
    # Bypass de condicionais
    sed -i 's/if-eqz/goto/g' "$file"
    sed -i 's/if-nez/goto/g' "$file"
done

echo "==== Customização concluída! ===="
