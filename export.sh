cat lib/inc/stk.s lib/inc/utils.s lib/src/stk.s lib/src/utils.s src/parser.s src/saver.s src/interpreter.s src/brainunfucker.s > export/fullcode
cd export

sed -i -e 's/brainunfucker/brainfuck/' fullcode
sed -i -e 's/.global brainfuck/tempstring/' fullcode
sed -i -e '/.global[ \t]/d' -e '/.include[ \t]/d' fullcode
sed -i -e 's/tempstring/.global brainfuck/' fullcode
sed -i -e 's/#.*$//' fullcode
sed -i -e '/^\s*$/d' fullcode

echo "# This is an export version of this project automatically generated and not meant for editing or reading." > tempfile
cat tempfile fullcode > brainfuck.s
rm tempfile fullcode

make && ./brainfuck ../$1