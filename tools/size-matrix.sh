#!/bin/sh
# Reproducible ReleaseSmall code-size experiment. The analysis linker accepts
# oversized images; the normal `zig build` keeps the real 16 KB limit.
set -eu

cd "$(dirname "$0")/.."
out_dir="zig-out/size-analysis"
mkdir -p "$out_dir"
csv="$out_dir/matrix.csv"
# Analysis variants overwrite zig-out/firmware. Always leave the flashable,
# 16 KB linker-script build in place, including when a probe fails.
trap 'zig build -Dmax_nodes=10 -Dmax_animations=0 -Doptimize=ReleaseSmall >/dev/null' EXIT
size_tool="${LLVM_SIZE:-llvm-size}"
if ! command -v "$size_tool" >/dev/null 2>&1; then
    size_tool="$(xcrun -f llvm-size)"
fi

default_variants='0:hal:0 1:core_text:0 2:low_pair:0 3:high_pair:0 4:focus_traversal:0 5:activate_typed:0 7:column:0 8:row:0 9:alignment_padding:0 19:text_repeat:0 20:button:0 21:checkbox:0 22:toggle:0 23:progress:0 24:icon:0 25:divider:0 26:panel:0 27:scrollbar:0 28:wrapped_text:0 29:tuner:0 30:knob:0 31:list:0 32:scroll_view:0 33:bitmap:0 40:c_text:0 41:c_checkbox:0 42:c_toggle:0 43:c_progress:0 44:c_icon:0 44:animation_capacity_1:1 45:animated_specs:1 60:renderer_init:0 61:pixel:0 62:hline:0 63:vline:0 64:line:0 65:rect:0 66:fill_rect:0 67:bitmap_primitive:0 68:font_draw:0 69:clip_pixel:0 80:diagnostics_on:0 81:finish_checked:0 82:raw_ids:0 83:diagnostics_no_screen:0 84:identity_rotate_xor:0 85:identity_addition:0'
variants="${*:-$default_variants}"

printf 'variant,label,animation_capacity,flash_bytes,delta_vs_v3,data_bytes,bss_bytes,static_ram,delta_ram_vs_v3,text_bytes,rodata_bytes\n' > "$csv"
zig build -Dmax_nodes=10 -Dmax_animations=0 -Doptimize=ReleaseSmall >/dev/null
reference_flash=$(wc -c < zig-out/firmware/firmware.bin | tr -d ' ')
reference_sections=$("$size_tool" -A zig-out/bin/firmware)
reference_text=$(printf '%s\n' "$reference_sections" | awk '$1 == ".text" { print $2 }')
reference_data=$(printf '%s\n' "$reference_sections" | awk '$1 == ".data" { print $2 }')
reference_bss=$(printf '%s\n' "$reference_sections" | awk '$1 == ".bss" { print $2 }')
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' 255 reference 0 "$reference_flash" '' "$reference_data" "$reference_bss" "$((reference_data + reference_bss))" '' "$reference_text" 0 >> "$csv"
printf '%-22s %7s B  data=%4s bss=%4s static=%4s\n' reference "$reference_flash" "$reference_data" "$reference_bss" "$((reference_data + reference_bss))" >&2
base_flash=''
base_ram=''
for entry in $variants; do
    old_ifs="$IFS"
    IFS=:
    set -- $entry
    IFS="$old_ifs"
    number="$1"
    label="$2"
    animations="$3"

    zig build -Dsize_variant="$number" -Dmax_nodes=10 -Dmax_animations="$animations" -Doptimize=ReleaseSmall >/dev/null
    # Retain symbol-rich ELFs only where attribution is most useful. Rebuild
    # any other variant by number when deeper inspection is needed.
    case "$number" in
        0|1|2|3|44|80|83|84|85)
            cp zig-out/bin/firmware "$out_dir/$label.elf"
            cp zig-out/firmware/firmware.bin "$out_dir/$label.bin"
            ;;
    esac
    flash=$(wc -c < zig-out/firmware/firmware.bin | tr -d ' ')
    sections=$("$size_tool" -A zig-out/bin/firmware)
    text_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".text" { print $2 }')
    rodata_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".rodata" { print $2 }')
    data_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".data" { print $2 }')
    bss_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".bss" { print $2 }')
    rodata_bytes="${rodata_bytes:-0}"
    static_ram=$((data_bytes + bss_bytes))
    if [ "$number" = 3 ]; then
        base_flash="$flash"
        base_ram="$static_ram"
    fi
    delta_flash=''
    delta_ram=''
    if [ -n "$base_flash" ]; then
        delta_flash=$((flash - base_flash))
        delta_ram=$((static_ram - base_ram))
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$number" "$label" "$animations" "$flash" "$delta_flash" "$data_bytes" "$bss_bytes" "$static_ram" "$delta_ram" "$text_bytes" "$rodata_bytes" >> "$csv"
    printf '%-22s %7s B  data=%4s bss=%4s static=%4s\n' "$label" "$flash" "$data_bytes" "$bss_bytes" "$static_ram" >&2
done
for animations in 0 1; do
    zig build -Dsize_analysis_reference=true -Dmax_nodes=10 -Dmax_animations="$animations" -Doptimize=ReleaseSmall >/dev/null
    cp zig-out/bin/firmware "$out_dir/reference_a$animations.elf"
    cp zig-out/firmware/firmware.bin "$out_dir/reference_a$animations.bin"
    flash=$(wc -c < zig-out/firmware/firmware.bin | tr -d ' ')
    sections=$("$size_tool" -A zig-out/bin/firmware)
    text_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".text" { print $2 }')
    data_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".data" { print $2 }')
    bss_bytes=$(printf '%s\n' "$sections" | awk '$1 == ".bss" { print $2 }')
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' 254 "reference_a$animations" "$animations" "$flash" "$((flash - base_flash))" "$data_bytes" "$bss_bytes" "$((data_bytes + bss_bytes))" "$((data_bytes + bss_bytes - base_ram))" "$text_bytes" 0 >> "$csv"
    printf '%-22s %7s B  data=%4s bss=%4s static=%4s\n' "reference_a$animations" "$flash" "$data_bytes" "$bss_bytes" "$((data_bytes + bss_bytes))" >&2
done
printf 'CSV: %s\n' "$csv" >&2
