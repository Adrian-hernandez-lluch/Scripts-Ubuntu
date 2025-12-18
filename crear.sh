#!/bin/bash
while IFS=, read -r grupo descripcion; do
  [ "$grupo" = "grupo" ] && continue
  groupadd -c "$descripcion" "$grupo" 2>/dev/null
done < departamentos.csv

while IFS=, read -r login password nombre a1 a2 desc dept; do
  [ "$login" = "login" ] && continue
  useradd -m -U -s /bin/bash -c "$nombre $a1 $a2 - $desc" "$login" 2>/dev/null
  usermod -aG "$dept" "$login"
  echo "$login:$password" | chpasswd
done < usuarios.csv
