STRING_MOD=modules/String-Extension
XW_MOD=modules/eXtraWidgets
XW_WIDGETS=$(shell ls modules/eXtraWidgets/xw/widgets)
XW_TARGET=modules/eXtraWidgets/xw
XW_WIDGET_JARS=$(addprefix xw/widgets/,$(XW_WIDGETS))
XW_WIDGET_SRCS=$(addprefix modules/eXtraWidgets/xw/widgets/,$(XW_WIDGETS))
LS_XW_MOD=modules/LSWidgets
LS_MOD=modules/LevelsSpace
SBT=env SBT_OPTS="-Xms512M -Xmx2048M -Xss6M -XX:+CMSClassUnloadingEnabled -XX:+UseConcMarkSweepGC -XX:MaxPermSize=724M" sbt

default: string/string.jar xw/xw.jar xw/widgets/LSWidgets ls/ls.jar

modules: $(STRING_MOD) modules/LevelsSpace modules/eXtraWidgets modules/LSWidgets
	mkdir -p modules
	git submodule update --init

$(STRING_MOD)/string.jar: $(STRING_MOD)/src
	make -C $(STRING_MOD) --file=Makefile

string/string.jar: $(STRING_MOD)/string.jar
	mkdir -p string
	cp $? $@

xw/xw.jar $(XW_WIDGET_JARS) $(XW_MOD)/xw/extrawidgets-api.jar: $(XW_MOD)/xw/src $(XW_MOD)/api/src $(XW_MOD)/core/src
	mkdir -p xw
	cd $(XW_MOD); $(SBT) package
	cp $(XW_TARGET)/json-simple-1.1.1.jar xw
	cp $(XW_TARGET)/extrawidgets-api.jar xw
	cp $(XW_TARGET)/extrawidgets-core.jar xw
	cp $(XW_TARGET)/xw.jar xw
	cp -r $(XW_TARGET)/widgets xw

$(LS_XW_MOD)/lib/extrawidgets-api.jar: $(XW_MOD)/xw/extrawidgets-api.jar
	mkdir -p $(LS_XW_MOD)/lib
	cp $? $@

xw/widgets/LSWidgets: xw/xw.jar $(LS_XW_MOD)/src $(LS_XW_MOD)/lib/extrawidgets-api.jar
	mkdir -p xw/widgets/LSWidgets
	cd $(LS_XW_MOD); $(SBT) package
	cp $(LS_XW_MOD)/*.jar xw/widgets/LSWidgets

ls/ls.jar: $(LS_MOD)/extensions/ls
	mkdir -p ls
	cp $(LS_MOD)/extensions/ls/* ls

$(LS_MOD)/extensions/ls: $(LS_MOD)/src
	cd $(LS_MOD); $(SBT) package

clean:
	rm -rf xw ls string
	git submodule foreach git clean -fdX
