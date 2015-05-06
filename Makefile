STRING_MOD=modules/String-Extension
XW_MOD=modules/eXtraWidgets
XW_WIDGET_NAMES=$(shell ls modules/eXtraWidgets/xw/widgets)
XW_WIDGETS=$(foreach widget,$(XW_WIDGET_NAMES), $(widget)/$(widget).jar)
XW_TARGET=modules/eXtraWidgets/xw
XW_WIDGET_JARS=$(addprefix xw/widgets/,$(XW_WIDGETS))
XW_WIDGET_SRCS=$(addprefix modules/eXtraWidgets/xw/widgets/,$(XW_WIDGETS))
XW_SRCS=$(shell find $(XW_MOD) -type f -name '*.scala')
LS_XW_MOD=modules/LSWidgets
LS_XW_SRCS=$(shell find $(LS_XW_MOD) -type f -name '*.scala')
LS_MOD=modules/LevelsSpace
LS_SRCS=$(shell find $(LS_MOD) -type f -name '*.java')
CF_MOD=modules/ControlFlowExtension
CF_SRCS=$(shell find $(CF_MOD) -type f -name '*.scala')
CL_MOD=modules/Custom-Logging-Extension
CF_SRCS=$(shell find $(CL_MOD) -type f -name '*.scala')
GIT_SHA1=$(shell git log | head -1 | cut -d\  -f2 )
GIT_SHA1_SHORT=$(shell echo $(GIT_SHA1) | sed 's/.\{32\}$$//' )
RELEASE_NAME=release-$(GIT_SHA1_SHORT)
EXTENSION_ROOTS=ls xw cf string custom-logging
SBT=env SBT_OPTS="-Xms512M -Xmx2048M -Xss6M -XX:+CMSClassUnloadingEnabled -XX:+UseConcMarkSweepGC -XX:MaxPermSize=724M" sbt

default: string/string.jar xw/xw.jar xw/widgets/LSWidgets/LSWidgets.jar ls/ls.jar cf/cf.jar custom-logging/custom-logging.jar

modules $(STRING_MOD) $(LS_MOD) $(XW_MOD) $(LS_XW_MOD) $(CF_MOD) $(CL_MOD): .git/modules/$(STRING_MOD) .git/modules/$(LS_MOD) .git/modules/$(XW_MOD) .git/modules/$(LS_XW_MOD) .git/modules/$(CF_MOD) .git/modules/$(CL_MOD)
	mkdir -p modules
	git submodule update --init
	touch modules

$(STRING_MOD)/string.jar: $(STRING_MOD)/src
	make -C $(STRING_MOD) --file=Makefile

string/string.jar: $(STRING_MOD)/string.jar
	mkdir -p string
	cp $? $@

xw/xw.jar $(XW_WIDGET_JARS) $(XW_MOD)/xw/extrawidgets-api.jar: $(XW_SRCS) $(XW_MOD)/xw/src $(XW_MOD)/api/src $(XW_MOD)/core/src
	mkdir -p xw
	cd $(XW_MOD); $(SBT) package
	cp $(XW_TARGET)/json-simple-1.1.1.jar xw
	cp $(XW_TARGET)/extrawidgets-api.jar xw
	cp $(XW_TARGET)/extrawidgets-core.jar xw
	cp $(XW_TARGET)/xw.jar xw
	cp -r $(XW_TARGET)/widgets xw
	find $(XW_TARGET)/widgets -type d | grep target | xargs rm -rf --

$(LS_XW_MOD)/lib/extrawidgets-api.jar: $(XW_MOD)/xw/extrawidgets-api.jar
	mkdir -p $(LS_XW_MOD)/lib
	cp $? $@

xw/widgets/LSWidgets xw/widgets/LSWidgets/LSWidgets.jar: xw/xw.jar $(LS_XW_MOD)/LSWidgets.jar
	mkdir -p xw/widgets/LSWidgets
	cp $(LS_XW_MOD)/*.jar xw/widgets/LSWidgets
	rm -f xw/widgets/LSWidgets/NetLogo*.jar

$(LS_XW_MOD)/LSWidgets.jar: $(LS_XW_SRCS) $(LS_XW_MOD)/src $(LS_XW_MOD)/lib/extrawidgets-api.jar
	cd $(LS_XW_MOD); $(SBT) package

ls/ls.jar: $(LS_MOD)/extensions/ls
	mkdir -p ls
	cp $(LS_MOD)/extensions/ls/* ls

$(LS_MOD)/extensions/ls: $(LS_MOD)/src $(LS_SRCS)
	cd $(LS_MOD); $(SBT) package

$(CF_MOD)/cf.jar: $(CF_MOD)/src $(CF_SRCS)
	cd $(CF_MOD); $(SBT) package

cf/cf.jar: $(CF_MOD)/cf.jar
	mkdir -p cf
	cp $(CF_MOD)/cf.jar cf/cf.jar

$(CL_MOD)/custom-logging.jar: $(CL_MOD)/src $(CL_SRCS)
	cd $(CL_MOD); $(SBT) package

custom-logging/custom-logging.jar: $(CL_MOD)/custom-logging.jar
	mkdir -p custom-logging
	cp $(CL_MOD)/custom-logging.jar custom-logging/custom-logging.jar

.PHONY: release
release: string/string.jar cf/cf.jar xw/xw.jar $(XW_WIDGET_JARS) ls/ls.jar xw/widgets/LSWidgets/LSWidgets.jar custom-logging/custom-logging.jar LevelSpaceXWGUI.nlogo
	mkdir -p dist/$(RELEASE_NAME)
	$(foreach dir,$(shell find $(EXTENSION_ROOTS)| egrep jar | grep -v target | sed "s;[^/]*\.jar;;g" | uniq),mkdir -p dist/$(RELEASE_NAME)/$(dir);)
	$(foreach jar,$(shell find $(EXTENSION_ROOTS) -type f -name '*.jar'),cp "$(jar)" "dist/$(RELEASE_NAME)/$(jar)";)
	cp LevelSpaceXWGUI.nlogo dist/$(RELEASE_NAME)
	cd dist && tar -czf $(RELEASE_NAME).tgz $(RELEASE_NAME)
	cd dist && zip -r $(RELEASE_NAME).zip $(RELEASE_NAME)

clean:
	rm -rf xw ls string cf custom-logging
	rm -rf dist/$(RELEASE_NAME)
	git submodule foreach git clean -fdX
