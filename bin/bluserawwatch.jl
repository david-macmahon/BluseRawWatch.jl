#!/bin/bash
#=
export JULIA_PROJECT=$(dirname $(dirname $(readlink -e "${BASH_SOURCE[0]}")))
exec julia --color=no --startup-file=no "${BASH_SOURCE[0]}" "$@"
=#

# This is primarily a script that used INotify.jl to watch for the creation and
# deletion of `*.0000.raw` files in/under a given list of top level directories.
#
# When a new `*.0000.raw` file is created, it gets added a node-specifc redis
# set that is indexed as "bluse_raw_watch:$node".  The value added to the set is a
# string containing the full pathname of the added file.
#
# When a `*.0000.raw` file is deleted, the full pathname of the deleted file
# will be removed from the Redis set.

using BluseRawWatch
using Redis
using INotify

function main(dir)
    redishost = get(ENV, "REDISHOST", "redishost")
    redis = Redis.RedisConnection(host=redishost)
    key = rediskey()

    @info "watching $dir"
    dw = INotify.DirWatcher(dirwatcher_callback, dir, INotify.CREATE|INotify.DELETE; redis=redis, key=key)

    Base.exit_on_sigint(false)
    try
        wait(dw.task[])
    catch e
        e isa InterruptException || rethrow()
    finally
        close(dw)
    end
end

if isempty(ARGS)
    println("usage: $(basename(PROGRAM_FILE)) DIR")
else
    main(ARGS[1])
end
