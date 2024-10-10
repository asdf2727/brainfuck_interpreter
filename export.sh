cat lib/inc/stk.s lib/inc/utils.s lib/src/stk.s lib/src/utils.s src/parser.s src/saver.s src/interpreter.s src/brainunfucker.s > fullcode

sed -i -e 's/brainunfucker/brainfuck/' fullcode
sed -i -e 's/.global brainfuck/tempstring/' fullcode
sed -i -e '/.global[ \t]/d' -e '/.include[ \t]/d' fullcode
sed -i -e 's/tempstring/.global brainfuck/' fullcode
sed -i -e 's/#.*$//' fullcode
sed -i -e '/^\s*$/d' fullcode

echo "# This is an automated export version of the project, not meant for editing or reading." > warningmsg
sed -e 's/./# &/' README.md > prefix
cat warningmsg prefix fullcode > export/brainfuck.s
rm warningmsg prefix fullcode

make && ./export/brainfuck $1