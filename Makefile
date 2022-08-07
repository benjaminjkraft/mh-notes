all: *.html

%.html: %.md Makefile
	pandoc -s --katex="https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/" $< -o $@
