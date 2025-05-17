#!/bin/bash

cd "$(cd "$(dirname "$0")";pwd)"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $@"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $@" >&2; }

declare -A RULES=(
  [Ad]="sort.py,filter-country-tld.py
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.mini.txt
https://raw.githubusercontent.com/ghvjjjj/adblockfilters/main/rules/adblockdnslite.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.xiaomi.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.oppo-realme.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.vivo.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.roku.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.lgwebos.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.tiktok.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.samsung.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.winoffice.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.amazon.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.apple.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.huawei.txt
"
  [Proxy]="sort.py
https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/tld-proxy.list
https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/proxy.list
https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/refs/heads/master/rule/Clash/Proxy/Proxy_Domain_For_Clash.txt
https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/refs/heads/release/gfw.txt
https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/refs/heads/release/proxy-list.txt
"
  [Direct]="sort.py
https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/cn.txt
https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/cn.list
https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/refs/heads/release/direct.txt
"
)

setup_mihomo_tool() {
  log "下载 Mihomo 工具"
  wget -q https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt || { error "版本获取失败"; exit 1; }
  version=$(cat version.txt)
  mihomo_tool="mihomo-linux-amd64-$version"
  wget -q "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/$mihomo_tool.gz" || { error "工具下载失败"; exit 1; }
  gzip -d "$mihomo_tool.gz"
  chmod +x "$mihomo_tool"
  log "Mihomo 工具就绪: $mihomo_tool"
}

process_rules() {
  local name=$1
  shift
  local scripts_line=$1
  shift
  local scripts=(${scripts_line//,/ })
  local urls=("$@")
  local domain_file="${name}_domain.txt"
  local tmp_file="${name}_tmp.txt"
  local mihomo_txt_file="${name}_Mihomo.txt"
  local mihomo_mrs_file="${mihomo_txt_file%.txt}.mrs"

  log "处理规则: $name"
  > "$domain_file"
  > "$tmp_file"
  for url in "${urls[@]}"; do
    curl --http2 --compressed --max-time 30 --retry 3 -sSL "$url" >> "$tmp_file" || echo "Failed: $url" >&2
  done
  cat "$tmp_file" >> "$domain_file"
  rm -f "$tmp_file"
  sed -i 's/\r//' "$domain_file"
  for script in "${scripts[@]}"; do
    python "$script" "$domain_file" || { error "脚本失败: $script"; return 1; }
    log "执行脚本: $script"
  done
  sed "s/^/\\+\\./g" "$domain_file" > "$mihomo_txt_file"
  ./"$mihomo_tool" convert-ruleset domain text "$mihomo_txt_file" "$mihomo_mrs_file"
  mv "$mihomo_txt_file" "../txt/$mihomo_txt_file"
  mv "$mihomo_mrs_file" "../$mihomo_mrs_file"
  log "生成: $mihomo_txt_file, $mihomo_mrs_file"
}

setup_mihomo_tool

for name in "${!RULES[@]}"; do
  IFS=$'\n' read -r scripts_line urls_lines <<< "${RULES[$name]}"
  IFS=$'\n' read -rd '' -a urls_arr <<< "$urls_lines"
  process_rules "$name" "$scripts_line" "${urls_arr[@]}" &
done

wait
rm -rf ./*.txt "$mihomo_tool" version.txt
log "全部完成，已清理"