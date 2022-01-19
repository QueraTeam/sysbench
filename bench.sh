#!/bin/bash

command -v curl >/dev/null || (apt update && apt install -y curl)

command -v sysbench >/dev/null; has_sysbench=$?
if [ "$has_sysbench" != "0" ]; then
  curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | bash
  apt install -y sysbench
fi

echo -e '\n\n'

echo '------------------- CPU BENCHMARK STARTED -------------------'
sysbench cpu run
echo -e '------------------- CPU BENCHMARK ENDED -------------------\n\n'
echo '------------------- MEMORY BENCHMARK STARTED -------------------'
sysbench memory run
echo -e '------------------- MEMORY BENCHMARK ENDED -------------------\n\n'
echo '------------------- FILEIO BENCHMARK STARTED -------------------'
sysbench fileio --file-test-mode=seqwr --file-total-size=20G run
echo -e '------------------- FILEIO BENCHMARK ENDED -------------------\n\n'

