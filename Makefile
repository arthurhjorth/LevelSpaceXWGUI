STRING_MOD=modules/String-Extension
XW_MOD=modules/eXtraWidgets
XW_WIDGETS=$(shell ls modules/eXtraWidgets/xw/widgets)
XW_TARGET=modules/eXtraWidgets/xw
XW_WIDGET_JARS=$(addprefix xw/widgets/,$(XW_WIDGETS))
XW_WIDGET_SRCS=$(addprefix modules/eXtraWidgets/xw/widgets/,$(XW_WIDGETS))

default: string/string.jar xw/xw.jar

modules: $(STRING_MOD) modules/LevelsSpace modules/eXtraWidgets modules/LSWidgets
	mkdir -p modules
	git submodule update --init

$(STRING_MOD)/string.jar: $(STRING_MOD)/src
	make -C $(STRING_MOD) --file=Makefile

string/string.jar: $(STRING_MOD)/string.jar
	mkdir -p string
	cp $? $@

xw/xw.jar $(XW_WIDGET_JARS): $(XW_MOD)/xw/src $(XW_MOD)/api/src $(XW_MOD)/core/src
	mkdir -p xw
	cd $(XW_MOD); sbt package
	cp $(XW_TARGET)/json-simple-1.1.1.jar xw
	cp -r $(XW_TARGET)/widgets xw
	cp -r $(XW_TARGET)/xw.jar xw
