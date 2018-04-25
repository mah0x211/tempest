package = "tempest"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-tempest.git"
}
description = {
    summary = "The Tempest",
    homepage = "https://github.com/mah0x211/lua-tempest",
    license = "",
    maintainer = "Masatoshi Fukunaga"
}
dependencies = {
    "lua >= 5.1",
    "act",
    "dump",
    "isa",
    "loadchunk",
    "net",
    "path",
    "signal",
    "string-split",
}
build = {
    type = "builtin",
    install = {
        bin = {
            tempest = "bin/command.lua"
        }
    },
    modules = {
        tempest = "lib/tempest.lua",
        ['tempest.eval'] = "lib/eval.lua",
        ['tempest.getopts'] = "lib/getopts.lua",
        ['tempest.logger'] = "lib/logger.lua",
    }
}
