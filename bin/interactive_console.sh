#!/bin/bash

# @author https://stackoverflow.com/questions/62049537/send-commands-directly-in-running-process-and-indirectly-e-g-with-tail
while IFS= read -rp '$ ' command; do
    printf '%s\n' "$command"
done >>/app/input.buffer
