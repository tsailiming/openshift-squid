#!/bin/bash

if [[ ! -d ${SQUID_CACHE_DIR}/00 ]]; then
    echo "Initializing cache..."
    squid -f /etc/squid/squid.conf --foreground -d 1 -z
fi

echo "Starting squid..."
squid -f /etc/squid/squid.conf --foreground -d 1
