#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

workspace_dir=$SCRIPT_DIR/../

sudo chown -R $(id -u):$(id -g) $workspace_dir

