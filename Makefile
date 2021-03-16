.PHONY:all

all: install
install:
	@for f in *;do\
		echo $$f;\
	done
