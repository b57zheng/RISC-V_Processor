for f in /home/b57zheng/ECE320_LAB/rv32-benchmarks/individual-instructions/*.x; do
    echo ">>> Running test with $f"
    make -s run TEST=test_pd MEM_PATH="$f"
done

for f in /home/b57zheng/ECE320_LAB/rv32-benchmarks/simple-programs/*.x; do
    echo ">>> Running test with $f"
    make -s run TEST=test_pd MEM_PATH="$f"
done
