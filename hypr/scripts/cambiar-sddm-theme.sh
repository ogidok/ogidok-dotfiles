#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="cambiar-sddm-theme.sh"
TARGET_CONF="/etc/sddm.conf.d/theme.conf"

# Prefer zenity because it is common and simple for this workflow; fallback to yad.
notify_fallback() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "SDDM Theme" "$msg" || true
  fi
}

GUI_TOOL=""
if command -v zenity >/dev/null 2>&1; then
  GUI_TOOL="zenity"
elif command -v yad >/dev/null 2>&1; then
  GUI_TOOL="yad"
else
  msg="Necesitas instalar zenity o yad para usar la GUI."
  echo "Error: $msg" >&2
  notify_fallback "$msg"
  exit 1
fi

show_error() {
  local msg="$1"
  notify_fallback "$msg"
  if [[ "$GUI_TOOL" == "zenity" ]]; then
    zenity --error --title="SDDM Theme" --text="$msg" || true
  else
    yad --error --title="SDDM Theme" --text="$msg" || true
  fi
}

show_info() {
  local msg="$1"
  if [[ "$GUI_TOOL" == "zenity" ]]; then
    zenity --info --title="SDDM Theme" --text="$msg" || true
  else
    yad --info --title="SDDM Theme" --text="$msg" || true
  fi
}

ask_yes_no() {
  local msg="$1"
  if [[ "$GUI_TOOL" == "zenity" ]]; then
    zenity --question --title="SDDM Theme" --text="$msg"
  else
    yad --question --title="SDDM Theme" --text="$msg"
  fi
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

safe_line() {
  local s="$1"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  printf '%s' "$s"
}

find_theme_preview_image() {
  local theme_dir="$1"
  local file

  for file in \
    "$theme_dir/preview.png" \
    "$theme_dir/Preview.png" \
    "$theme_dir/screenshot.png" \
    "$theme_dir/Screenshot.png" \
    "$theme_dir/preview.jpg" \
    "$theme_dir/Preview.jpg" \
    "$theme_dir/preview.jpeg" \
    "$theme_dir/Preview.jpeg" \
    "$theme_dir/preview.webp" \
    "$theme_dir/Preview.webp"; do
    if [[ -f "$file" ]]; then
      printf '%s' "$file"
      return 0
    fi
  done

  file="$(find "$theme_dir" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | head -n 1 || true)"
  if [[ -n "$file" ]]; then
    printf '%s' "$file"
  fi
}

open_preview_image() {
  local image_path="$1"

  if [[ -z "$image_path" || ! -f "$image_path" ]]; then
    show_info "El theme seleccionado no incluye imagen de preview."
    return 0
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$image_path" >/dev/null 2>&1 &
    return 0
  fi

  show_info "No se encontro xdg-open para abrir la preview."
}

parse_ini_file_theme() {
  local file="$1"
  local section=""
  local line key value

  [[ -r "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%%;*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      section="$(trim "${BASH_REMATCH[1]}")"
      continue
    fi

    [[ "$line" == *"="* ]] || continue
    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    if [[ "$section" == "Theme" ]]; then
      if [[ "$key" == "Current" && -n "$value" ]]; then
        CURRENT_THEME="$value"
      elif [[ ("$key" == "ThemeDir" || "$key" == "ThemesDir") && -n "$value" ]]; then
        THEME_DIR_CANDIDATES+=("$value")
      fi
    fi
  done < "$file"
}

collect_sddm_config_files() {
  local -a files=()
  local dir file

  for dir in \
    /usr/lib/sddm/sddm.conf.d \
    /usr/local/lib/sddm/sddm.conf.d \
    /lib/sddm/sddm.conf.d \
    /etc/sddm.conf.d; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      files+=("$file")
    done < <(find "$dir" -maxdepth 1 -type f -name '*.conf' | sort)
  done

  if [[ -f /etc/sddm.conf ]]; then
    files+=("/etc/sddm.conf")
  fi

  SDDM_CONFIG_FILES=("${files[@]}")
}

read_example_config_theme_dir() {
  local section=""
  local line key value

  command -v sddm >/dev/null 2>&1 || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%%;*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      section="$(trim "${BASH_REMATCH[1]}")"
      continue
    fi

    [[ "$line" == *"="* ]] || continue
    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    if [[ "$section" == "Theme" && ( "$key" == "ThemeDir" || "$key" == "ThemesDir" ) && -n "$value" ]]; then
      THEME_DIR_CANDIDATES+=("$value")
    fi
  done < <(sddm --example-config 2>/dev/null || true)
}

unique_existing_theme_dirs() {
  local -A seen=()
  local dir
  THEME_DIRS=()

  for dir in "${THEME_DIR_CANDIDATES[@]}"; do
    [[ -n "$dir" ]] || continue
    [[ "$dir" == /* ]] || continue
    if [[ -d "$dir" && -z "${seen[$dir]+x}" ]]; then
      seen[$dir]=1
      THEME_DIRS+=("$dir")
    fi
  done
}

read_theme_metadata() {
  local theme_dir="$1"
  local id name author description metadata_file preview preview_label

  id="$(basename "$theme_dir")"
  name="$id"
  author=""
  description=""
  preview="$(find_theme_preview_image "$theme_dir")"
  preview_label="no"
  if [[ -n "$preview" ]]; then
    preview_label="si"
  fi

  for metadata_file in \
    "$theme_dir/metadata.desktop" \
    "$theme_dir/theme.conf" \
    "$theme_dir/metadata"; do
    [[ -f "$metadata_file" ]] || continue

    if grep -q '^Name=' "$metadata_file"; then
      name="$(grep -m1 '^Name=' "$metadata_file" | cut -d'=' -f2-)"
    fi
    if grep -q '^Author=' "$metadata_file"; then
      author="$(grep -m1 '^Author=' "$metadata_file" | cut -d'=' -f2-)"
    fi
    if grep -q '^Description=' "$metadata_file"; then
      description="$(grep -m1 '^Description=' "$metadata_file" | cut -d'=' -f2-)"
    fi
    break
  done

  THEME_IDS+=("$id")
  THEME_NAMES+=("$(safe_line "$name")")
  THEME_AUTHORS+=("$(safe_line "$author")")
  THEME_DESCRIPTIONS+=("$(safe_line "$description")")
  THEME_PREVIEWS+=("$preview")
  THEME_PREVIEW_LABELS+=("$preview_label")
}

collect_themes() {
  local dir theme_path

  THEME_IDS=()
  THEME_NAMES=()
  THEME_AUTHORS=()
  THEME_DESCRIPTIONS=()
  THEME_PREVIEWS=()
  THEME_PREVIEW_LABELS=()

  for dir in "${THEME_DIRS[@]}"; do
    while IFS= read -r theme_path; do
      read_theme_metadata "$theme_path"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
  done
}

pick_theme_with_gui() {
  local i selected default text_dirs
  text_dirs="$(printf '%s\n' "${THEME_DIRS[@]}")"

  if [[ "$GUI_TOOL" == "zenity" ]]; then
    local -a args
    args=(
      --list
      --title "Seleccionar theme de SDDM"
      --width=980
      --height=600
      --text "Theme actual: ${CURRENT_THEME:-desconocido}\n\nRutas detectadas:\n${text_dirs}"
      --radiolist
      --column "Usar"
      --column "Theme"
      --column "Nombre"
      --column "Autor"
      --column "Descripcion"
      --column "Preview"
      --print-column=2
    )

    for i in "${!THEME_IDS[@]}"; do
      default="FALSE"
      if [[ -n "$CURRENT_THEME" && "${THEME_IDS[$i]}" == "$CURRENT_THEME" ]]; then
        default="TRUE"
      fi
      args+=("$default" "${THEME_IDS[$i]}" "${THEME_NAMES[$i]}" "${THEME_AUTHORS[$i]:-(sin autor)}" "${THEME_DESCRIPTIONS[$i]:-(sin descripcion)}" "${THEME_PREVIEW_LABELS[$i]}")
    done

    selected="$(zenity "${args[@]}" 2>/dev/null)" || return 1
    printf '%s' "$selected"
    return 0
  fi

  local -a rows
  for i in "${!THEME_IDS[@]}"; do
    default="FALSE"
    if [[ -n "$CURRENT_THEME" && "${THEME_IDS[$i]}" == "$CURRENT_THEME" ]]; then
      default="TRUE"
    fi
    rows+=("$default" "${THEME_IDS[$i]}" "${THEME_NAMES[$i]}" "${THEME_AUTHORS[$i]:-(sin autor)}" "${THEME_DESCRIPTIONS[$i]:-(sin descripcion)}" "${THEME_PREVIEW_LABELS[$i]}")
  done

  selected="$(yad \
    --list \
    --title="Seleccionar theme de SDDM" \
    --width=980 --height=600 \
    --text="Theme actual: ${CURRENT_THEME:-desconocido}\n\nRutas detectadas:\n${text_dirs}" \
    --radiolist \
    --column="Usar:CHK" \
    --column="Theme" \
    --column="Nombre" \
    --column="Autor" \
    --column="Descripcion" \
    --column="Preview" \
    --print-column=2 \
    "${rows[@]}" 2>/dev/null)" || return 1

  printf '%s' "$selected"
}

get_theme_preview_by_id() {
  local selected="$1"
  local i
  for i in "${!THEME_IDS[@]}"; do
    if [[ "${THEME_IDS[$i]}" == "$selected" ]]; then
      printf '%s' "${THEME_PREVIEWS[$i]}"
      return 0
    fi
  done
  printf ''
}

confirm_or_preview_theme() {
  local selected="$1"
  local preview_path="$2"
  local msg

  msg="Theme seleccionado: $selected"
  if [[ -n "$preview_path" ]]; then
    msg+="\nPreview: disponible"
  else
    msg+="\nPreview: no disponible"
  fi

  if [[ "$GUI_TOOL" == "zenity" ]]; then
    local response=""
    response="$(zenity --question \
      --title="Confirmar theme" \
      --text="$msg" \
      --ok-label="Aplicar" \
      --cancel-label="Cancelar" \
      --extra-button="Previsualizar" 2>/dev/null)"
    local status=$?

    if [[ "$status" -eq 0 ]]; then
      if [[ "$response" == "Previsualizar" ]]; then
        open_preview_image "$preview_path"
        return 10
      fi
      return 0
    fi
    return 1
  fi

  yad --question \
    --title="Confirmar theme" \
    --text="$msg" \
    --button="Previsualizar:2" \
    --button="Aplicar:0" \
    --button="Cancelar:1" >/dev/null 2>&1
  local status=$?

  if [[ "$status" -eq 2 ]]; then
    open_preview_image "$preview_path"
    return 10
  fi

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  return 1
}

apply_theme() {
  local selected="$1"
  local helper
  local err_log

  if [[ ! "$selected" =~ ^[A-Za-z0-9._+-]+$ ]]; then
    show_error "Nombre de theme invalido: $selected"
    exit 1
  fi

  helper="$(mktemp)"
  cat > "$helper" <<'ROOTSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

theme="$1"
install -d -m 0755 /etc/sddm.conf.d

tmp_file="$(mktemp /etc/sddm.conf.d/theme.conf.tmp.XXXXXX)"
cat > "$tmp_file" <<EOF
[Theme]
Current=$theme
EOF
chmod 0644 "$tmp_file"
mv "$tmp_file" /etc/sddm.conf.d/theme.conf
ROOTSCRIPT
  chmod 0700 "$helper"
  err_log="$(mktemp)"

  local ok=0
  if command -v pkexec >/dev/null 2>&1; then
    if pkexec "$helper" "$selected" 2>"$err_log"; then
      ok=1
    fi
  elif command -v sudo >/dev/null 2>&1; then
    if sudo "$helper" "$selected" 2>"$err_log"; then
      ok=1
    fi
  else
    rm -f "$helper"
    rm -f "$err_log"
    show_error "No se encontro pkexec ni sudo. Instala polkit y/o sudo."
    exit 1
  fi

  local err_text=""
  if [[ -s "$err_log" ]]; then
    err_text="$(tr '\n' ' ' < "$err_log")"
  fi

  rm -f "$helper"
  rm -f "$err_log"

  if [[ "$ok" -ne 1 ]]; then
    if [[ "$err_text" == *"No authentication agent found"* ]]; then
      show_error "No hay agente polkit en sesion. Inicia uno (ej. polkit-gnome) y vuelve a intentar."
    else
      show_error "No se pudo aplicar el theme. Revisa permisos de polkit/sudo.\nDetalle: ${err_text:-sin detalle}"
    fi
    exit 1
  fi
}

main() {
  CURRENT_THEME=""
  THEME_DIR_CANDIDATES=(
    "/usr/share/sddm/themes"
    "/usr/local/share/sddm/themes"
  )

  collect_sddm_config_files
  local conf
  for conf in "${SDDM_CONFIG_FILES[@]}"; do
    parse_ini_file_theme "$conf"
  done

  read_example_config_theme_dir
  unique_existing_theme_dirs

  if [[ "${#THEME_DIRS[@]}" -eq 0 ]]; then
    show_error "No se encontraron rutas de themes de SDDM en el sistema."
    exit 1
  fi

  collect_themes
  if [[ "${#THEME_IDS[@]}" -eq 0 ]]; then
    show_error "No se encontraron themes dentro de: ${THEME_DIRS[*]}"
    exit 1
  fi

  local selected exists i preview_path decision
  while true; do
    if ! selected="$(pick_theme_with_gui)"; then
      # Cancelar no hace cambios
      exit 0
    fi

    if [[ -z "$selected" ]]; then
      exit 0
    fi

    exists=0
    for i in "${!THEME_IDS[@]}"; do
      if [[ "${THEME_IDS[$i]}" == "$selected" ]]; then
        exists=1
        break
      fi
    done

    if [[ "$exists" -ne 1 ]]; then
      show_error "El theme seleccionado no es valido: $selected"
      exit 1
    fi

    preview_path="$(get_theme_preview_by_id "$selected")"

    if confirm_or_preview_theme "$selected" "$preview_path"; then
      decision=0
    else
      decision=$?
    fi

    if [[ "$decision" -eq 10 ]]; then
      continue
    fi

    if [[ "$decision" -ne 0 ]]; then
      exit 0
    fi

    apply_theme "$selected"
    show_info "Theme aplicado: $selected\nArchivo actualizado: $TARGET_CONF\n\nRecarga SDDM reiniciando la sesion o el servicio si quieres probarlo de inmediato."
    break
  done
}

main "$@"
