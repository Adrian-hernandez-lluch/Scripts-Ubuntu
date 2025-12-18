#!/bin/bash

# 1) Borrar usuarios (incluye /home)
while IFS=, read -r login; do
  [ "$login" = "login" ] && continue
  userdel -r "$login" 2>/dev/null || true
done < borrar_usuarios.csv

# 2) Borrar grupos (departamentos)
while IFS=, read -r grupo; do
  [ "$grupo" = "grupo" ] && continue
  groupdel "$grupo" 2>/dev/null || true
done < borrar_grupos.csv
