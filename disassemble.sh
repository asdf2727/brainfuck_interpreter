set -e

if	[ $# -le 1 ]
then	out="code.s"
else	out=$2
fi

make > /dev/null
./bin/brainfuck $1 > hexcode
objdump -D -b binary -m i386:x86-64 hexcode > code
sed -i -e "1,7d" -e ":a; s/\s[0-9a-f]\{2\}\s/ /; ta" -e "s/^\s*\([^\s:]*\):\s*\(.*\)/\1:\t\t\2/" code
echo $1 > name
cat name code > $out
rm hexcode code name