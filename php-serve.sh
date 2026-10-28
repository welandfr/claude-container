#!/usr/bin/env bash
# Serve a PHP project with PHP's built-in web server on a published port.
#
#   php-serve [docroot] [port]     defaults: current directory, 8000
#
# Binds 0.0.0.0, not localhost: a server listening only on the container's
# loopback is unreachable through docker's port publishing. The host side is
# still restricted to 127.0.0.1 by the launcher's -p mapping. With several
# instances running, the host port is shifted (8001, 8002, …) — the launcher
# prints the mapping on startup.
set -e

docroot=${1:-.}
port=${2:-${PHP_SERVE_PORT:-8000}}

# Requests for paths that don't exist fall back to the docroot's index.php, so
# front-controller frameworks work without a router script.
exec php -S "0.0.0.0:$port" -t "$docroot"
