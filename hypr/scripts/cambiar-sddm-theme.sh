#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="cambiar-sddm-theme.sh"
TARGET_CONF="/etc/sddm.conf.d/theme.conf"
MAIN_CONF="/etc/sddm.conf"
PREVIEW_MAX_WIDTH=260
PREVIEW_MAX_HEIGHT=150
PREVIEW_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cambiar-sddm-theme/previews"

# Prefer yad for inline previews in list; fallback to zenity.
notify_fallback() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "SDDM Theme" "$msg" || true
  fi
}

GUI_TOOL=""
if command -v yad >/dev/null 2>&1; then
  GUI_TOOL="yad"
elif command -v zenity >/dev/null 2>&1; then
  GUI_TOOL="zenity"
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

build_preview_thumbnail() {
  local source_img="$1"
  local theme_id="$2"
  local key out

  [[ -n "$source_img" && -f "$source_img" ]] || {
    printf '%s' ""
    return 0
  }

  mkdir -p "$PREVIEW_CACHE_DIR"
  key="$(printf '%s' "$source_img" | sha1sum | awk '{print $1}')"
  out="$PREVIEW_CACHE_DIR/${theme_id}-${key}.png"

  if [[ ! -s "$out" ]]; then
    if command -v magick >/dev/null 2>&1; then
      magick "$source_img" -auto-orient -thumbnail "${PREVIEW_MAX_WIDTH}x${PREVIEW_MAX_HEIGHT}>" "$out" 2>/dev/null || true
    elif command -v convert >/dev/null 2>&1; then
      convert "$source_img" -auto-orient -thumbnail "${PREVIEW_MAX_WIDTH}x${PREVIEW_MAX_HEIGHT}>" "$out" 2>/dev/null || true
    fi
  fi

  if [[ -s "$out" ]]; then
    printf '%s' "$out"
  else
    # Fallback if thumbnail generation is unavailable.
    printf '%s' "$source_img"
  fi
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
  local id name author description metadata_file preview

  id="$(basename "$theme_dir")"
  name="$id"
  author=""
  description=""
  preview=""

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
    if grep -q -E '^(Screenshot|ScreenShot)=' "$metadata_file"; then
      preview="$(grep -m1 -E '^(Screenshot|ScreenShot)=' "$metadata_file" | cut -d'=' -f2-)"
      if [[ -n "$preview" && "$preview" != /* ]]; then
        preview="$theme_dir/$preview"
      fi
      if [[ ! -f "$preview" ]]; then
        preview=""
      fi
    fi
    break
  done

  # Common preview filenames used by many SDDM themes.
  if [[ -z "$preview" ]]; then
    local candidate
    for candidate in \
      "$theme_dir/preview.png" \
      "$theme_dir/preview.jpg" \
      "$theme_dir/preview.jpeg" \
      "$theme_dir/preview.webp" \
      "$theme_dir/Preview.png" \
      "$theme_dir/screenshot.png" \
      "$theme_dir/screenshot.jpg" \
      "$theme_dir/screenshots/preview.png" \
      "$theme_dir/artwork/preview.png"; do
      if [[ -f "$candidate" ]]; then
        preview="$candidate"
        break
      fi
    done
  fi

  if [[ -n "$preview" ]]; then
    preview="$(build_preview_thumbnail "$preview" "$id")"
  fi

  THEME_IDS+=("$id")
  THEME_NAMES+=("$(safe_line "$name")")
  THEME_AUTHORS+=("$(safe_line "$author")")
  THEME_DESCRIPTIONS+=("$(safe_line "$description")")
  THEME_PREVIEWS+=("$preview")
}

collect_themes() {
  local dir theme_path

  THEME_IDS=()
  THEME_NAMES=()
  THEME_AUTHORS=()
  THEME_DESCRIPTIONS=()
  THEME_PREVIEWS=()

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
      --text "Theme actual: ${CURRENT_THEME:-desconocido}\n\nRutas detectadas:\n${text_dirs}\n\nNota: para preview inline instala yad."
      --radiolist
      --column "Usar"
      --column "Theme"
      --column "Nombre"
      --column "Autor"
      --column "Descripcion"
      --print-column=2
    )

    for i in "${!THEME_IDS[@]}"; do
      default="FALSE"
      if [[ -n "$CURRENT_THEME" && "${THEME_IDS[$i]}" == "$CURRENT_THEME" ]]; then
        default="TRUE"
      fi
      args+=("$default" "${THEME_IDS[$i]}" "${THEME_NAMES[$i]}" "${THEME_AUTHORS[$i]:-(sin autor)}" "${THEME_DESCRIPTIONS[$i]:-(sin descripcion)}")
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
    rows+=("$default" "${THEME_IDS[$i]}" "${THEME_NAMES[$i]}" "${THEME_AUTHORS[$i]:-(sin autor)}" "${THEME_DESCRIPTIONS[$i]:-(sin descripcion)}" "${THEME_PREVIEWS[$i]}")
  done

  selected="$(yad \
    --list \
    --title="Seleccionar theme de SDDM" \
    --width=1200 --height=640 \
    --text="Theme actual: ${CURRENT_THEME:-desconocido}\n\nRutas detectadas:\n${text_dirs}" \
    --radiolist \
    --column="Usar:CHK" \
    --column="Theme" \
    --column="Nombre" \
    --column="Autor" \
    --column="Descripcion" \
    --column="Preview:IMG" \
    --print-column=2 \
    --expand-column=4 \
    "${rows[@]}" 2>/dev/null)" || return 1

  printf '%s' "$selected"
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

# Keep /etc/sddm.conf aligned, because it may override /etc/sddm.conf.d/theme.conf
if [[ -f /etc/sddm.conf ]]; then
  tmp_main="$(mktemp /etc/sddm.conf.tmp.XXXXXX)"
  awk -v theme="$theme" '
    BEGIN {
      in_theme = 0
      theme_seen = 0
      current_set = 0
    }
    {
      line = $0
      if (line ~ /^\[.*\]$/) {
        if (in_theme && !current_set) {
          print "Current=" theme
          current_set = 1
        }

        if (line == "[Theme]") {
          in_theme = 1
          theme_seen = 1
        } else {
          in_theme = 0
        }

        print line
        next
      }

      if (in_theme && line ~ /^[[:space:]]*Current[[:space:]]*=/) {
        if (!current_set) {
          print "Current=" theme
          current_set = 1
        }
        next
      }

      print line
    }
    END {
      if (in_theme && !current_set) {
        print "Current=" theme
      }

      if (!theme_seen) {
        if (NR > 0) {
          print ""
        }
        print "[Theme]"
        print "Current=" theme
      }
    }
  ' /etc/sddm.conf > "$tmp_main"
  chmod 0644 "$tmp_main"
  mv "$tmp_main" /etc/sddm.conf
fi
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

  local selected
  if ! selected="$(pick_theme_with_gui)"; then
    # Cancelar no hace cambios
    exit 0
  fi

  if [[ -z "$selected" ]]; then
    exit 0
  fi

  local exists=0
  local i
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

  if ! ask_yes_no "Aplicar el theme '$selected' en $TARGET_CONF (y sincronizar $MAIN_CONF si existe)?"; then
    exit 0
  fi

  apply_theme "$selected"

  show_info "Theme aplicado: $selected\nArchivo actualizado: $TARGET_CONF\nArchivo sincronizado si existe: $MAIN_CONF\n\nRecarga SDDM reiniciando la sesion o el servicio si quieres probarlo de inmediato."
}

main "$@"
