set -e

min_time=100000000

make

for test in $*
do
	echo -e "\n\n"
	echo $test

	cat < $test.in | ./bin/brainfuck $test > out_file

	output_status="$(cmp --silent out_file $test.out; echo $?)"
	if [ $output_status -ne 0 ]; then
		#diff <(hexdump $test.in | sed -e 's/^\S*\s*//') <(hexdump out_file | sed -e 's/^\S*\s*//')
		echo "Wrong output"
		rm out_file
		continue
	fi
	rm out_file
	echo "Correct output"

	> code_file
	> in_file
	for i in $(seq 1 $rep_count)
	do
		cat $test >> code_file
		cat $test.in >> in_file
	done
	hyperfine "cat < in_file | ./bin/brainfuck code_file" "cat < in_file | ./bin/brainfuck_pancake_0 code_file"
	rm code_file in_file
done
