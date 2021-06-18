#!/bin/bash

echo "Starting squid..."
squid -f /etc/squid/squid.conf --foreground -d 1
