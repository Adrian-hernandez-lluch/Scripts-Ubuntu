#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso:"
  echo "  $0 crear  departamentos.csv usuarios.csv"
  echo "  $0 borrar borrar_usuarios.csv borrar_grupos.csv"
  exit 1
}

# --- util ---
read_csv_lines() { tail -n +2 "$1"; }

trim_quotes() {
  local s="$1"
  s="${s%\"}"; s="${s#\"}"
  s="${s%\'}"; s="${s#\'}"
  echo "$s"
}

group_exists() { getent group "$1" >/dev/null 2>&1; }
user_exists() { id "$1" >/dev/null 2>&1; }

# --- crear grupos ---
create_groups() {
  local dept_csv="$1"
  while IFS=, read -r grp desc; do
    grp="$(trim_quotes "$grp")"
    desc="$(trim_quotes "$desc")"
    [[ -z "$grp" ]] && continue

    if group_exists "$grp"; then
      echo "[OK] Grupo ya existe: $grp"
    else
      groupadd -c "$desc" "$grp"
      echo "[ADD] Grupo creado: $grp"
    fi
  done < <(read_csv_lines "$dept_csv")
}

# --- crear usuarios ---
create_users() {
  local users_csv="$1"

  while IFS=, read -r login pass nombre ap1 ap2 udesc dept; do
    login="$(trim_quotes "$login")"
    pass="$(trim_quotes "$pass")"
    nombre="$(trim_quotes "$nombre")"
    ap1="$(trim_quotes "$ap1")"
    ap2="$(trim_quotes "$ap2")"
    udesc="$(trim_quotes "$udesc")"
    dept="$(trim_quotes "$dept")"

    [[ -z "$login" ]] && continue

    if ! group_exists "$dept"; then
      echo "[ERR] No existe el grupo/departamento '$dept' para el usuario '$login'"
      exit 1
    fi

    # GECOS: "Nombre Apellido1 Apellido2 - descripcion"
    local gecos="${nombre} ${ap1} ${ap2} - ${udesc}"

    if user_exists "$login"; then
      echo "[OK] Usuario ya existe: $login (se asegura pertenencia a $dept)"
      usermod -aG "$dept" "$login"
      continue
    fi

    # -m home, -s shell, -U crea grupo propio del usuario
    useradd -m -s /bin/bash -U -c "$gecos" "$login"
    usermod -aG "$dept" "$login"

    # Asigna contraseña (si no cumple la política, fallará)
    echo "${login}:${pass}" | chpasswd

    # Opcional: forzar cambio en próximo inicio (descomenta si tu enunciado lo exige)
    # chage -d 0 "$login"

    echo "[ADD] Usuario creado: $login (dept: $dept)"
  done < <(read_csv_lines "$users_csv")
}

# --- borrar ---
delete_users() {
  local del_users_csv="$1"
  while IFS=, read -r login; do
    login="$(trim_quotes "$login")"
    [[ -z "$login" ]] && continue
    if user_exists "$login"; then
      userdel -r "$login" || true
      echo "[DEL] Usuario borrado: $login"
    else
      echo "[SKIP] Usuario no existe: $login"
    fi
  done < <(read_csv_lines "$del_users_csv")
}

delete_groups() {
  local del_groups_csv="$1"
  while IFS=, read -r grp; do
    grp="$(trim_quotes "$grp")"
    [[ -z "$grp" ]] && continue
    if group_exists "$grp"; then
      if groupdel "$grp"; then
        echo "[DEL] Grupo borrado: $grp"
      else
        echo "[WARN] No se pudo borrar el grupo '$grp' (¿tiene miembros?)"
      fi
    else
      echo "[SKIP] Grupo no existe: $grp"
    fi
  done < <(read_csv_lines "$del_groups_csv")
}

main() {
  [[ $# -lt 3 ]] && usage

  local mode="$1"
  case "$mode" in
    crear)
      [[ $# -ne 3 ]] && usage
      create_groups "$2"
      create_users "$3"
      ;;
    borrar)
      [[ $# -ne 3 ]] && usage
      delete_users "$2"
      delete_groups "$3"
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
