"""
    run_watcher(args...)

This is primarily a function that uses `INotify.DirWatcher` to watch for the
creation and deletion of `*.0000.raw` files in/under one or more top level
directories.  If no arguments are passed, the `ARGS` Vector is used.

When a new `*.0000.raw` file is created, it gets added a node-specifc redis
set that is indexed as "bluse_raw_watch:\$hostname".  The value added to the
set is a string containing the full pathname of the added file.

When a `*.0000.raw` file is deleted, the full pathname of the deleted file
will be removed from the Redis set.

This is a long running function.  It never returns until interrupted by
Ctrl-C.  It is intended to be used from the command line by:

```sh
julia --project=BLUSE_RAW_WATCH_DIR -e 'using BluseRawWatch; run_watcher()' -- DIR [DIR...]
```
"""
function run_watcher(args...)
    if isempty(args)
        args = ARGS
        if isempty(args)
            error("no directory given")
        end
    end
    dirs = args

    redishost = get(ENV, "REDISHOST", "redishost")
    redis = Redis.RedisConnection(host=redishost)
    key = rediskey()

    # Remove all stale members from redis set
    remove_stale_entries(redis)

    @info "watching $(join(dirs, " "))"
    dw = INotify.DirWatcher(dirwatcher_callback, dirs, INotify.CREATE|INotify.DELETE; redis=redis, key=key)

    Base.exit_on_sigint(false)
    try
        wait(dw.task[])
    catch e
        e isa InterruptException || rethrow()
    finally
        close(dw)
    end
end
