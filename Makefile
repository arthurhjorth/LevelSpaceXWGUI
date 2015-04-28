STRING_MOD=modules/String-Extension

default: string/string.jar

modules: $(STRING_MOD) modules/LevelsSpace modules/eXtraWidgets modules/LSWidgets
	mkdir -p modules
	git submodule update --init

setup: string xw ls
	mkdir string
	mkdir xw
	mkdir ls

$(STRING_MOD)/string.jar: $(STRING_MOD)/src
	make -C $(STRING_MOD) --file=Makefile

string/string.jar: $(STRING_MOD)/string.jar
	mkdir -p string
	cp $? $@
