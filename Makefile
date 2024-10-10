build = obj/main.o obj/read_file.o obj/parser.o obj/saver.o obj/interpreter.o obj/brainunfucker.o lib/obj/utils.o lib/obj/stk.o
.PHONY: clean

bin/brainfuck: $(build) | bin
	$(CC) -no-pie -o "$@" $^

lib/obj:
	mkdir lib/obj
obj:
	mkdir obj
bin:
	mkdir bin

lib/obj/%.o: lib/src/%.s | lib/obj
	$(CC) -no-pie -c -o "$@" "$<"
obj/%.o: src/%.s | obj
	$(CC) -no-pie -c -o "$@" "$<"

clean:
	rm -rf obj lib/obj
