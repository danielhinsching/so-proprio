#!/usr/bin/env bash
# Ajustes de desempenho para HD mecânico. Carregado com `source`.
# Todas as funções recebem caminhos explícitos para poderem ser testadas fora do sistema real.

# set_noatime <fstab>: adiciona noatime em / e /home (ext4).
# Guarda o fstab original uma única vez, escreve num temporário no mesmo diretório,
# verifica com findmnt e só então troca (mv é atômico).
set_noatime() {
  local fstab="$1" tmp changed
  local findmnt_cmd="${FINDMNT_CMD:-findmnt}"
  [ -f "$fstab" ] || { echo "fstab não encontrado: $fstab" >&2; return 1; }
  [ -e "$fstab.so-proprio.bak" ] || cp -p "$fstab" "$fstab.so-proprio.bak"
  tmp="$(mktemp "$fstab.XXXXXX")" || return 1
  changed="$(awk -v out="$tmp" '
    $1 !~ /^#/ && NF >= 4 && ($2 == "/" || $2 == "/home") && $3 == "ext4" {
      matched++
      n = split($4, o, ",")
      has = 0
      for (i = 1; i <= n; i++) if (o[i] == "noatime") has = 1
      if (!has) {
        $4 = $4 ",noatime"
        line = $1
        for (i = 2; i <= NF; i++) line = line "\t" $i
        print line > out
        next
      }
    }
    { print > out }
    END { print matched + 0 }
  ' "$fstab")" || { rm -f "$tmp"; return 1; }
  if [ "$changed" -eq 0 ]; then
    echo "Aviso: nenhuma linha ext4 para / ou /home em $fstab; noatime não aplicado."
  fi
  # Só bloqueia se a mudança piorou: original válido e novo inválido.
  # (Um fstab que já falha, por exemplo com um disco externo ausente, não deve travar o ajuste.)
  if "$findmnt_cmd" --verify --tab-file "$fstab" >/dev/null 2>&1 \
     && ! "$findmnt_cmd" --verify --tab-file "$tmp" >/dev/null 2>&1; then
    echo "ERRO: o novo fstab não passou na verificação (findmnt --verify); nada foi alterado." >&2
    rm -f "$tmp"
    return 1
  fi
  chmod --reference="$fstab" "$tmp"
  chown --reference="$fstab" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$fstab"
}

# write_sysctl <root>
write_sysctl() {
  local dir="$1/etc/sysctl.d"
  mkdir -p "$dir"
  printf '# so-proprio: menos swap, mais RAM (medir e ajustar entre 10 e 20)\nvm.swappiness=10\n' \
    > "$dir/99-so-proprio.conf"
}

# _set_kv <arquivo> <CHAVE> <valor>: substitui a linha CHAVE= ativa ou acrescenta no fim.
_set_kv() {
  local file="$1" key="$2" value="$3"
  touch "$file"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

# write_zram <root>: zram com zstd usando 25% da RAM (valores iniciais, medir).
write_zram() {
  local dir="$1/etc/default"
  mkdir -p "$dir"
  _set_kv "$dir/zramswap" ALGO zstd
  _set_kv "$dir/zramswap" PERCENT 25
}

# write_udev <root>: agendador bfq para discos rotacionais.
write_udev() {
  local dir="$1/etc/udev/rules.d"
  mkdir -p "$dir"
  cat > "$dir/60-so-proprio-bfq.rules" <<'RULE'
# so-proprio: agendador bfq para HD mecânico (discos rotacionais)
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
RULE
}

# disable_services <nome>...: desativa as unidades .service, .socket e .path que existem
# (socket/path reativariam o serviço sob demanda, por exemplo o CUPS ao imprimir).
disable_services() {
  local cmd="${SYSTEMCTL:-systemctl}" svc unit
  for svc in "$@"; do
    for unit in "$svc.socket" "$svc.path" "$svc.service"; do
      if "$cmd" list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^${unit//./\\.}[[:space:]]"; then
        echo "Desativando $unit"
        "$cmd" disable --now "$unit"
      fi
    done
  done
}
