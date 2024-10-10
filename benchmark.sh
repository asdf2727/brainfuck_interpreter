make && 
hyperfine --warmup=$1 './bin/brainfuck {FILE}' -L FILE $2