# Orchid - WebRTC P2P VPN Market (on Ethereum)
# Copyright (C) 2017-2020  The Orchid Authors

# GNU Affero General Public License, Version 3 {{{ */
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# }}}


include $(pwd)/target-all.mk
engine := $(pwd/flutter)/bin/cache/artifacts/engine/$(platform)$(engine)

rsync := rsync -a --delete

$(output)/$(machine)/package/data/flutter_assets/AssetManifest%json: $(dart)
	rm -rf .dart_tool/flutter_build $(output)/$(machine)/flutter
	cd $(pwd/gui) && $(flutter) assemble \
	    -dTargetPlatform="$(platform)" \
	    -dTargetFile="lib/main.dart" \
	    -dBuildMode="$(mode)" \
	    -dTreeShakeIcons="false" \
	    -dTrackWidgetCreation="true" \
	    --output="$(CURDIR)/$(output)/$(machine)/flutter" \
	    $(mode)_bundle_$(mismatch)_assets
	@mkdir -p $(dir $@)
	$(rsync) $(output)/$(machine)/flutter/flutter_assets/ $(dir $@)
signed += $(output)/$(machine)/package/data/flutter_assets/AssetManifest.json

source += $(filter-out \
    %/engine_method_result.cc \
    %_unittests.cc \
,$(wildcard $(pwd)/engine/shell/platform/common/client_wrapper/*.cc))

cflags += -I$(pwd)/engine/shell/platform/common/{client_wrapper,public}

cflags += -I$(pwd/gui)/$(assemble)
source += $(subst %,.,$(word 1,$(generated)))
header += $(subst %,.,$(word 2,$(generated)))

# XXX: does flutter enforce that windows uses .cpp and linux uses .cc or is that an accident?
source += $(wildcard $(pwd/gui)/$(assemble)/flutter/ephemeral/.plugin_symlinks/*/$(assemble)/*.cc)
source += $(wildcard $(pwd/gui)/$(assemble)/flutter/ephemeral/.plugin_symlinks/*/$(assemble)/*.cpp)

cflags += -I$(pwd/gui)/$(assemble)/flutter/ephemeral{/cpp_client_wrapper/include{/flutter,},}
cflags += $(patsubst %,-I%,$(wildcard $(pwd/gui)/$(assemble)/flutter/ephemeral/.plugin_symlinks/*/$(assemble)/include))
cflags += -DFLUTTER_PLUGIN_IMPL

template := $(pwd/flutter)/packages/flutter_tools/templates/app_shared/$(assemble).tmpl

$(output)/$(machine)/package/data/icudtl.dat: $(pwd/flutter)/bin/cache/artifacts/engine/$(platform)/icudtl.dat
	@mkdir -p $(dir $@)
	cp -f $< $@
signed += $(output)/$(machine)/package/data/icudtl.dat
