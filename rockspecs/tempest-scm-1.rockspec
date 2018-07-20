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
    "act >= 0.9.1",
    "dump >= 0.1.1",
    "isa >= 0.1.0",
    "loadchunk >= 0.1.0",
    "net >= 0.24.0",
    "net-http >= 0.1.2",
    "path >= 1.1.0",
    "signal >= 1.2.0",
    "string-split >= 0.2.0",
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
        ['tempest.bootstrap'] = "lib/bootstrap.lua",
        ['tempest.env'] = "lib/env.lua",
        ['tempest.getopts'] = "lib/getopts.lua",
        ['tempest.handler'] = "lib/handler.lua",
        ['tempest.ipc'] = "lib/ipc.lua",
        ['tempest.logger'] = "lib/logger.lua",
        ['tempest.script'] = "lib/script.lua",
        ['tempest.worker'] = "lib/worker.lua",
        ['tempest.handler.echo'] = "handler/echo.lua",
        ['tempest.protocol.http'] = "protocol/http.lua",
    }
}
