#!/usr/bin/env bash

sed -i "$1" -e \
  '
   s_"ssh-[^"]*"_""_;
   s_\("\| \)[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\("\| \)_\11.1.1.1\2_;
   s_"i-[0-9a-f]*"_""_
   s_"sg-[0-9a-f]*"_""_
  '
