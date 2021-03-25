#!/bin/bash

if [[ ! -d /var/spool/squid/00 ]]; then
    echo "Initializing cache..."
    squid -f /etc/squid/squid.conf --foreground -d 1 -z
fi

echo "Starting squid..."
squid -f /etc/squid/squid.conf --foreground -d 1