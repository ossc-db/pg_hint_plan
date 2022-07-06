#!/bin/bash
set -e

# Clean and build pg_hint_plan
make -C /pg_hint_plan clean all USE_PGXS=1

# Install pg_hint_plan so postgres will start with shared_preload_libraries set
sudo bash -c "PATH=${PATH?} make -C /pg_hint_plan install USE_PGXS=1"

# Start postgres
${PGBIN}/pg_ctl -w start -D ${PGDATA}

# Test pg_hint_plan
make -C /pg_hint_plan installcheck USE_PGXS=1