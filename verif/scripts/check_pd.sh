#!/usr/bin/env bash
set -euo pipefail

# Directory containing generated traces
TRACE_DIR="${TRACE_DIR:-/home/b57zheng/ECE320_LAB/b57zheng-pd5/verif/sim/verilator/test_pd}"

if [[ ! -d "$TRACE_DIR" ]]; then
  echo "Trace directory not found: $TRACE_DIR" >&2
  exit 1
fi

shopt -s nullglob
traces=("$TRACE_DIR"/*.trace)
if (( ${#traces[@]} == 0 )); then
  echo "No .trace files in $TRACE_DIR" >&2
  exit 1
fi

overall_status=0
printf "%-30s  %-6s  %s\n" "trace" "result" "final_value"
printf "%-30s  %-6s  %s\n" "-----" "------" "-----------"

for trace in "${traces[@]}"; do
  base=$(basename "$trace")
  # Individual instruction tests start with rv32ui-p and use x3; others use x10.
  if [[ "$base" == rv32ui-p* ]]; then
    target_rd=3
  else
    target_rd=10
  fi

  # awk prints "RESULT VALUE"
  read -r result final_val <<<"$(awk -v rd_target="$target_rd" '
    function to_int(s,    i,c,val,d) {
      gsub(/^0x/,"",s)
      s=tolower(s)
      if (s ~ /^[0-9]+$/) return s+0
      val=0
      for (i=1; i<=length(s); i++) {
        c=substr(s,i,1)
        d=index("0123456789abcdef", c) - 1
        if (d < 0) return 0
        val = val*16 + d
      }
      return val
    }
    function norm_hex(s){ gsub(/^0x/,"",s); return tolower(s) }

    ($1=="[D]" || $1=="[d]") {
      pc = norm_hex($2)
      opcode = norm_hex($3)
      rd = norm_hex($4)
      rs1 = norm_hex($5)
      imm = norm_hex($8)
      # Treat decoded bubbles (addi x0,x0,0) as invalid instructions
      if (opcode=="13" && rd=="00" && rs1=="00" && imm=="00000000")
        bubble_pc[pc] = 1
      else
        bubble_pc[pc] = 0
    }

    ($1=="[W]" || $1=="[w]") {
      if ($3=="1") {
        pc = norm_hex($2)
        rd = to_int($4)
        data = to_int($5)
        if (!bubble_pc[pc] && rd == rd_target) last = data
      }
    }
    END {
      if (last == "") { print "NO_VALID_WRITE -"; exit }
      if (last == 1) { print "PASS", last } else { print "FAIL", last }
    }
  ' "$trace")"

  printf "%-30s  %-6s  %s\n" "$base" "$result" "$final_val"
  if [[ "$result" != "PASS" ]]; then
    overall_status=1
  fi
done

exit "$overall_status"
