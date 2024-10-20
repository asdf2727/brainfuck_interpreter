## TODO

- [x] use addb with 0x0(%rbx) before a jump if you can to avoid using a cmpb
- [x] also set 0x0(%rbx) to $0 when multiplying to avoid wasted instructions
- [x] bring back multiplier to optimise loops
	- [x] clear when multiplier is 0
	- [x] move when multiplier is 1
	- [x] shift when multiplier is power of 2
	- [x] do the same for negatives
	- [x] don't actually write the multiplier calculation if you don't need it (stuff like `[-]`)
- [x] remove imul operations whenever possible
- [x] prepare syscall registers IN ADVANCE to avoid wasting instructions on mov $1, %reg
- [x] use offset for write/read instructions
- [x] use buffering for output to avoid using syscalls too many times
- [ ] use registers for variables where possible
- [x] don't use a je before optimised loops if loops are short
- [x] skip calculating multiplier if no values depend on it
- [ ] use xmm for additions if enough adds are close together (preferably alligned)
- [ ] try to see if move and add is faster than add with offset even if sorted

# RANT 1

Hi! I'm writing this at 12:35 AM, 16/09/2024 in the first day of coding this monstruosity.

This is supposed to be an efficient brainfuck interpreter that:

1. parses the entire text and optimizes everything it can
2. saves the optimised code as an "intermediary" language in the heap using the heap stack I made myself (see stk.s)
3. runs the intermediary code super fast, using a circular buffer for the memory tape (see cbuf.s)

Since for now I'm still working on the parser I don't know exactly how it'll end up but here are some optimiztions that i thought of:

- [x] run all consecutive +/- and >/< operations in a single operation. This might actually be the biggest optimization since a normal program is full of long strings of the same symbol
- [x] run loops that:
	1. don't have other loops inside them
	2. start and end at the same ptr position
	3. don't have I/O operations
as a single run, multiplying the normal +/- operation by the number of repetitions
e.g. `[<++++>-]` would be converted to `*(ptr-1) += 4 * *(ptr); *(ptr) = 0`
this should help with a lot of tedious operations of this kind that always pop up in brainfuck programs
- [x] make the "intermediary" language actually just hex instructions and run it natively
this would make it blazing fast, but it would also burn my brain trying to understand how to write and run code in the heap

These are all the ideas I had until now, but we'll see how many end up in the final version

# RANT 2

I'm about to rant for a few paragraphs, for useful stuff see [TODO](#todo).

Hi again! 08/10/2024, nearly a month later, I realize that this project was more addictive than I thought. Initially I just planned for it to be a fun adventure to see how fast I can get the code to run, and in the beginning it was indeed fun.

The problem arised some time ago with the 'cheese' major version of the program, which tried to implement. The second optimization (the multiplication vs loop one) and ended up being slower. Hooray! That was one week of my life wasted and caused me a temporary burnout.

After that, I managed to get the JIT compilation working, over the course of which I learned a lot about how assembly is actually represented in hex code (I managed to find the 2 chapters in the 2000 page Intel manual that I was interested in). After I got it to work, I found the one moment of happiness working on this project, due to a x6 speed increase for the Mandelbrot script.

After that I did one small optimization and called it a day. I mean, I was pretty happy with my results. I planned to start working on a renderer for the 11th assignment, the x86 game.

Only, that one small optimization actually didn't help at all. Moreover, when I tested it with another script, the Hanoi one, it ended up being SIGNIFICANTLY slower. This made zero sense because I simply reduced the number of instructions in my compiled code. Instead of doing `addb $1, %rax; addb $1, (%rax); addb $1, %rax; addb $1, (%rax)`... I just did `addb $1, 0x1(%rax); addb $1, 0x2(%rax);` and added an `addb $whatever, %rax` at the end. It does exactly the same things, just with half of the instructions, but it's slower.

I don't know for the life of me why this happens, and I more or less accepted it as just the lottery of how your specific program runs, but now I'm at a point where I NEED to make it faster to restore what's left of my pride. It's not about liking it anymore, I'm just addicted to optimizations. And now here we are.

Thank you for allowing me to share my struggles with this project, and it might also help you to learn a valuable lesson:

**ALWAYS TEST AND BENCHMARK ANY OPTIMIZATION TO MAKE SURE IT'S ACTUALLY FASTER!** Only god and the guys at intel know how the processor works!
