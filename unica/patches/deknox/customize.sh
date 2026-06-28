#!/bin/bash

# ==========================================================
# Project NERV - DeKnox & System Optimization Script (Final)
# Alvo: Galaxy A52s 5G (a52sxq)
# ==========================================================

# --- FUNÇÕES DE COMPATIBILIDADE ---
# Definimos as funções aqui para garantir que o script funcione mesmo em sub-shells
DELETE_FROM_WORK_DIR() {
    local partition=$1
    local path=$2
    local target="work/$partition/$path"
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "[-] Removendo: $target"
        rm -rf "$target"
    fi
}

# --- INÍCIO DA CUSTOMIZAÇÃO ---

# Remove configuração de Blockchain
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_BLOCKCHAIN_SERVICE" --delete

# Configurações específicas de Partição/Dispositivo
if [ "$TARGET_SINGLE_SYSTEM_IMAGE" == "qssi" ]; then
    ADD_TO_WORK_DIR "a05snsdxx" "system" "."
elif [ "$TARGET_SINGLE_SYSTEM_IMAGE" == "essi" ]; then
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/bin" 0 2000 751 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/lib/libandroid_servers.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/lib/libmdf.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/lib64/libandroid_servers.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/lib64/libepm.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "gts9fexx" "system" "system/lib64/libmdf.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ "$TARGET_SINGLE_SYSTEM_IMAGE" == "self" ]; then
    return 0
fi

# --- SEÇÃO DE REMOÇÃO DO KNOX (DEKNOX) ---
echo "==== Iniciando DeKnox Avançado ===="

# Apps e Serviços do Knox
KNOX_APPS=(
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

for app in "${KNOX_APPS[@]}"; do
    DELETE_FROM_WORK_DIR "system" "$app"
done

# Limpeza de Permissões e XMLs (Geral)
echo "[-] Limpando arquivos de configuração do Knox..."
find work/system/system/etc/permissions/ -type f \( -name "*knox*" -o -name "*secure*" \) -exec rm -f {} +
find work/system/system/etc/sysconfig/ -type f -name "*knox*" -exec rm -f {} +

# Bibliotecas do Knox
for libdir in "lib" "lib64"; do
    LIBS=(
        "libdualdar.so" "libepm.so" "libpersona.so" "libsec_sem.so" 
        "libsec_semRil.so" "libsec_semTlc.so" "libtlc_payment_spay.so"
    )
    for lib in "${LIBS[@]}"; do
        DELETE_FROM_WORK_DIR "system" "system/$libdir/$lib"
    done
done

# Fabric Crypto (Android 14+)
if [[ "$TARGET_API_LEVEL" -ge 34 ]]; then
    DELETE_FROM_WORK_DIR "system" "system/bin/fabric_crypto"
    DELETE_FROM_WORK_DIR "system" "system/etc/init/fabric_crypto.rc"
    DELETE_FROM_WORK_DIR "system" "system/priv-app/KmxService"
fi

# --- SEÇÃO DE PATCHES DINÂMICOS (BYPASS) ---
echo "==== Aplicando patches dinâmicos de bypass do Knox ===="

# Localiza arquivos smali para patch dentro da pasta de trabalho
SMALI_FILES=$(find . -type f \( -name "*Policy.smali" -o -name "*Manager.smali" \) | grep -E "Knox|DualDAR|Hdm")

patch_smali_advanced() {
    local file=$1
    if [ -f "$file" ]; then
        echo "[+] Patching: $file"
        # Força retorno falso em métodos de verificação
        sed -i '/.method.*isKnoxEnabled/I,/.end method/ s/return.*/const\/4 v0, 0x0\n    return v0/g' "$file"
        sed -i '/.method.*getKnoxVersion/I,/.end method/ s/return-object.*/const\/4 v0, 0x0\n    return-object v0/g' "$file"
        # Bypass de condicionais
        sed -i 's/if-eqz/goto/g' "$file"
        sed -i 's/if-nez/goto/g' "$file"
    fi
}

for smali in $SMALI_FILES; do
    patch_smali_advanced "$smali"
done

echo "==== Customização finalizada com sucesso! ===="
