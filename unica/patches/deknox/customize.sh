#!/bin/bash

# ==========================================================
# Project NERV - DeKnox & System Optimization Script
# Alvo: Galaxy A52s 5G (a52sxq)
# ==========================================================

# Remove configuração de Blockchain (não suportado/necessário)
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
echo "[-] Removendo binários e apps do Knox..."

# Apps e Serviços
DELETE_FROM_WORK_DIR "system" "system/app/BlockchainBasicKit"
DELETE_FROM_WORK_DIR "system" "system/bin/dualdard"
DELETE_FROM_WORK_DIR "system" "system/bin/sem_daemon"
DELETE_FROM_WORK_DIR "system" "system/etc/init/dualdard.rc"
DELETE_FROM_WORK_DIR "system" "system/priv-app/HdmApk"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KPECore"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxCore"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxERAgent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxFrameBufferProvider"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxGuard"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxMposAgent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxNetworkFilter"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxNeuralNetworkRuntime"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxPushManager"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxSandbox"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxZtFramework"
DELETE_FROM_WORK_DIR "system" "system/priv-app/SEMFactoryApp"
DELETE_FROM_WORK_DIR "system" "system/priv-app/knoxanalyticsagent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/knoxvpnproxyhandler"

# Permissões e XMLs
find work/system/system/etc/permissions/ -name "*knox*" -type f -delete
find work/system/system/etc/permissions/ -name "*secure*" -type f -delete
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/com.samsung.android.nfc.mpos.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.hdmapp.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.kgclient.xml"

# Bibliotecas (Lib e Lib64)
echo "[-] Removendo bibliotecas do Knox..."
for libdir in "lib" "lib64"; do
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libdualdar.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libepm.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libpersona.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libsec_sem.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libsec_semRil.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libsec_semTlc.so"
    DELETE_FROM_WORK_DIR "system" "system/$libdir/libtlc_payment_spay.so"
done

# Fabric Crypto (Android 14+)
if [[ "$TARGET_API_LEVEL" -ge 34 ]]; then
    DELETE_FROM_WORK_DIR "system" "system/bin/fabric_crypto"
    DELETE_FROM_WORK_DIR "system" "system/etc/init/fabric_crypto.rc"
    DELETE_FROM_WORK_DIR "system" "system/priv-app/KmxService"
fi

# --- SEÇÃO DE PATCHES DINÂMICOS (BYPASS) ---
echo "==== Aplicando patches dinâmicos de bypass do Knox ===="

# Localiza arquivos smali para patch
# Nota: O find deve buscar dentro do diretório de extração da ROM
SMALI_FILES=$(find . -type f -name "*Policy.smali" -o -name "*Manager.smali" | grep -E "Knox|DualDAR|Hdm")

patch_smali_advanced() {
    local file=$1
    if [ -f "$file" ]; then
        echo "[+] Patching: $file"
        
        # 1. Forçar retorno falso (0x0) em métodos de verificação de integridade/Knox
        # Procura por métodos que retornam booleanos ou objetos e injeta o retorno nulo
        sed -i '/.method.*isKnoxEnabled/I,/.end method/ s/return.*/const\/4 v0, 0x0\n    return v0/g' "$file"
        sed -i '/.method.*getKnoxVersion/I,/.end method/ s/return-object.*/const\/4 v0, 0x0\n    return-object v0/g' "$file"
        
        # 2. Remover saltos condicionais (Bypass de IFs)
        sed -i 's/if-eqz/goto/g' "$file"
        sed -i 's/if-nez/goto/g' "$file"
        
        echo "    [OK] $file modificado."
    fi
}

for smali in $SMALI_FILES; do
    patch_smali_advanced "$smali"
done

# Limpeza de logs e arquivos temporários de build
rm -rf work/system/system/etc/init/knox*

echo "==== Customização concluída com sucesso! ===="
