import Config

# The REPL_MODE file-logging backend was removed in 0.5.0. It was reachable only
# by exporting REPL_MODE=true before the application started, which nothing did
# and which the `repl` command itself did not do -- so the CLI's own REPL never
# triggered it. Revisit file logging as a feature in its own right if it is
# wanted, rather than as a side effect of an environment variable.
