#!/bin/sh
command=$1
if [ "$command" = "" ]
then
  command="--update"
fi
default="--install"
if [ $command = $default ] #注意这里的空格不能少！
then
#    echo " bundle exec lg install --no-repo-update"
    bundle exec lg install --no-repo-update --verbose
else
#    echo " bundle exec lg update --no-repo-update"
    bundle exec lg update --no-repo-update --verbose
fi
