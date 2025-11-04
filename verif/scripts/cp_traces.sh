#!/usr/bin/env bash
set -euo pipefail

GOLDEN_DIR="../golden"
MINE_DIR="../sim/verilator/test_pd"
MAX_LINES=3000   # soft cap; we also stop at first SYSTEM (ecall)

normalize_and_filter() {
  awk -v max_lines="$MAX_LINES" '
    function dc(i){ $i="-" }
    function lower_all(){ for (i=1;i<=NF;i++){ gsub(/^0x/,"",$i); $i=tolower($i) } }
    function emit_line(){ print; out_lines++; if (out_lines >= max_lines) exit }
    function hex2int(h,    i,c,val){
      val = 0
      for (i = 1; i <= length(h); i++) {
        c = substr(h, i, 1)
        d = index("0123456789abcdef", c) - 1
        if (d < 0) return 0
        val = val * 16 + d
      }
      return val
    }
    function supported(op){
      return (op=="37" || op=="17" || op=="6f" || op=="67" ||
              op=="63" || op=="03" || op=="23" || op=="13" || op=="33")
    }

    BEGIN { haveF=0; emit=0; lastop=""; stop=0; out_lines=0; program_base=hex2int("01000000") }

    $1=="[F]" || $1=="[f]" {
      if (stop) next
      lower_all()
      pc_val = hex2int($2)
      if (pc_val < program_base) { stop=1; exit 0 }
      lastF=$0; haveF=1; next
    }

    $1=="[D]" || $1=="[d]" {
      if (stop) next
      lower_all()
      op=$3; f3=$7; f7=$8

      # Stop at first SYSTEM (ecall/ebreak/csrs etc.)
      if (op=="73") { stop=1; exit 0 }

      emit = supported(op) ? 1 : 0
      if (!emit) next
      lastop = op

      if (haveF) { print lastF; haveF=0; out_lines++; if (out_lines >= max_lines) exit }

      # ---- [D] dont-care masking by opcode ----
      if (op=="33"){ dc(9); dc(10) }                                 # R
      else if (op=="13"){ dc(6); if (f3=="001"||f3=="101"){ dc(9) }  # I(OP-IMM)
                                else { dc(8); dc(10) } }
      else if (op=="03"){ dc(6); dc(8); dc(10) }                     # LOAD
      else if (op=="67"){ dc(6); dc(7); dc(8); dc(10) }              # JALR
      else if (op=="23"){ dc(4); dc(8); dc(10) }                     # STORE
      else if (op=="63"){ dc(4); dc(8); dc(10) }                     # BRANCH
      else if (op=="37" || op=="17"){ dc(5); dc(6); dc(7); dc(8); dc(10) } # U LUI/AUIPC
      else if (op=="6f"){ dc(5); dc(6); dc(7); dc(8); dc(10) }       # J JAL

      emit_line(); next
    }

    ($1=="[R]" || $1=="[r]") {
      if (stop || !emit) next
      lower_all()
      # [R] fields: [r] rs1 rs2 data_rs1 data_rs2
      if (lastop=="37" || lastop=="17" || lastop=="6f") { dc(2); dc(3); dc(4); dc(5) }
      else if (lastop=="67" || lastop=="03" || lastop=="13") { dc(3); dc(5) }
      emit_line(); next
    }

    ($1=="[E]" || $1=="[e]") {
      if (stop || !emit) next
      lower_all(); emit_line(); next
    }

    ($1=="[M]" || $1=="[m]") {
      if (stop || !emit) next
      lower_all()

      # [M] fields: [m] pc mem_addr read_write access_size mem_data
      if (!(lastop=="03" || lastop=="23")) {
        # Non-memory instructions: address/size/data are dont cares
        dc(3); dc(5); dc(6);
      } else if ($4=="0") {
        # Loads: memory data not checked in golden reference
        dc(6);
      }
      emit_line(); next
    }

    ($1=="[W]" || $1=="[w]") {
      if (stop || !emit) next
      lower_all()
      # [W] fields: [w] pc write_enable write_rd data_rd
      if ($3=="0") { dc(4); dc(5) }   # no register write: rd/data dont matter
      emit_line(); next
    }

    { if (!stop && emit) { lower_all(); emit_line() } }
  ' "$1"
}

for gold in "$GOLDEN_DIR"/*.trace; do
  base=$(basename "$gold")
  mine="$MINE_DIR/$base"

  if [[ -f "$mine" ]]; then
    # Normalize into temps so we can count lines
    gtmp=$(mktemp) ; mtmp=$(mktemp)
    normalize_and_filter "$gold" | head -n "$MAX_LINES" > "$gtmp"
    normalize_and_filter "$mine" | head -n "$MAX_LINES" > "$mtmp"

    gcount=$(wc -l < "$gtmp" | tr -d ' ')
    mcount=$(wc -l < "$mtmp" | tr -d ' ')

    echo ">>> Comparing $base  (lines compared: golden=$gcount, mine=$mcount; stop at SYSTEM, mask DCs)"

    if diff -u "$gtmp" "$mtmp" > "diff_${base}.log"; then
      echo " Match"
      rm -f "diff_${base}.log"
    else
      echo " Differences found (see diff_${base}.log)"
    fi

    rm -f "$gtmp" "$mtmp"
  else
    echo ">>> Skipping $base (no matching file in $MINE_DIR)"
  fi
done
