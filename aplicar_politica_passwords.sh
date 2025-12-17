#!/usr/bin/env bash
set -euo pipefail

echo "[+] Aplicando política de contraseñas en Ubuntu 24.04"

# ─────────────────────────────────────────────
# 0. Comprobar ejecución como root
# ─────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "[-] Ejecuta este script como root: sudo $0"
  exit 1
fi

FECHA=$(date +%F_%H%M%S)

backup() {
  if [[ -f "$1" ]]; then
    cp -a "$1" "$1.bak.$FECHA"
  fi
}

# ─────────────────────────────────────────────
# 1. Instalar paquetes necesarios
# ─────────────────────────────────────────────
apt update -y
apt install -y libpam-pwquality libpam-modules libpwquality-tools

# ─────────────────────────────────────────────
# 2. Copias de seguridad
# ─────────────────────────────────────────────
backup /etc/security/pwquality.conf
backup /etc/pam.d/common-password
backup /etc/pam.d/common-auth
backup /etc/login.defs

# ─────────────────────────────────────────────
# 3. Política de calidad de contraseñas
# ─────────────────────────────────────────────
sed -i '/^# --- BEGIN POLITICA CONTRASEÑAS ---$/,/^# --- END POLITICA CONTRASEÑAS ---$/d' /etc/security/pwquality.conf

cat << 'EOF' >> /etc/security/pwquality.conf

# --- BEGIN POLITICA CONTRASEÑAS ---
minlen = 12
dcredit = -1
ucredit = -2
lcredit = -1
ocredit = -2
maxrepeat = 3
difok = 5
usercheck = 1
gecoscheck = 1
# --- END POLITICA CONTRASEÑAS ---
EOF

# ─────────────────────────────────────────────
# 4. PAM: pwquality + historial
# ─────────────────────────────────────────────
sed -i '/pam_pwhistory.so/d' /etc/pam.d/common-password

if grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
  sed -i 's/^password\s\+requisite\s\+pam_pwquality\.so.*/password requisite pam_pwquality.so retry=3/' /etc/pam.d/common-password
else
  sed -i '/pam_unix.so/i password requisite pam_pwquality.so retry=3' /etc/pam.d/common-password
fi

sed -i '/pam_pwquality.so/a password required pam_pwhistory.so remember=5 use_authtok' /etc/pam.d/common-password

# ─────────────────────────────────────────────
# 5. Bloqueo por intentos fallidos
# ─────────────────────────────────────────────
sed -i '/pam_faillock.so/d' /etc/pam.d/common-auth
sed -i '/pam_faillock.so/d' /etc/pam.d/common-account

sed -i '1i auth required pam_faillock.so preauth silent deny=4 unlock_time=3600' /etc/pam.d/common-auth

sed -i '/pam_unix.so/a auth [default=die] pam_faillock.so authfail deny=4 unlock_time=3600' /etc/pam.d/common-auth

echo 'account required pam_faillock.so' >> /etc/pam.d/common-account

# ─────────────────────────────────────────────
# 6. Caducidad de contraseñas
# ─────────────────────────────────────────────
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   45/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

echo "[+] Política aplicada correctamente"
