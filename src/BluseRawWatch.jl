module BluseRawWatch

export rediskey
export dirwatcher_callback
export run_watcher

using Redis
using INotify

include("run_watcher.jl")

function rediskey()
    hostname = split(gethostname(), '.')[1]
    "bluse_raw_watch:$hostname"
end

function dirwatcher_callback(dir_event_name; redis, key)
    try
        dir, event, name = dir_event_name
        # Ignore events for files that don't end with ".0000.raw"
        endswith(name, ".0000.raw") || return
        path = joinpath(dir, name)
        if INotify.iscreate(event)
            @info "adding $path to $key"
            sadd(redis, key, path)
        elseif INotify.isdelete(event)
            @info "removing $path from $key"
            srem(redis, key, path)
        end
    catch
        for (exc, bt) in Base.catch_stack()
            showerror(stderr, exc, bt)
            println(stderr)
        end
    end
end

end # module BluseRawWatch
