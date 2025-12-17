#!/bin/bash

echo "=== Configurando política de contraseñas en Ubuntu ==="

# 1. Instalar módulos necesarios
echo "[1/6] Instalando módulos..."
sudo apt update -y
sudo apt install -y libpam-pwquality libpam-pwhistory pwscore

# 2. Configurar pwquality
echo "[2/6] Configurando /etc/security/pwquality.conf ..."
sudo bash -c 'cat > /etc/security/pwquality.conf' << 'EOF'
minlen = 12
dcredit = -1
dcredit_max = 3
ucredit = -2
ucredit_max = 4
ocredit = -3
maxrepeat = 3
dictcheck = 1
usercheck = 1
EOF

# 3. Configurar historial de contraseñas
echo "[3/6] Configurando historial de contraseñas..."
sudo sed -i '/pam_pwhistory.so/d' /etc/pam.d/common-password
sudo sed -i '/pam_unix.so/ i password requisite pam_pwhistory.so remember=5 enforce_for_root' /etc/pam.d/common-password

# 4. Configurar bloqueo por intentos fallidos
echo "[4/6] Configurando bloqueo tras intentos fallidos..."
sudo sed -i '/pam_tally2.so/d' /etc/pam.d/common-auth
sudo sed -i '1 i auth required pam_tally2.so deny=4 unlock_time=3600 onerr=fail audit' /etc/pam.d/common-auth

# 5. Configurar expiración por defecto para nuevos usuarios
echo "[5/6] Configurando expiración por defecto..."
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   45/' /etc/login.defs
sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

# 6. Ocultar usuarios en la pantalla de login (GDM)
echo "[6/6] Ocultando usuarios en pantalla de login..."
sudo mkdir -p /etc/gdm3/custom.conf.d
echo -e "[greeter]\nIncludeAll=false" | sudo tee /etc/gdm3/custom.conf
# Para ocultar usuarios específicos, añade archivos como este:
# echo -e "[User]\nHidden=true" | sudo tee /etc/gdm3/custom.conf.d/nombre_usuario.conf

echo "=== Política de contraseñas configurada correctamente ==="
echo "Usa 'chage -l usuario' para verificar la expiración de cada cuenta."
