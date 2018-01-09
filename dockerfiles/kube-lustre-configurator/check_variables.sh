#!/bin/sh

for i in $(cat $1 | grep -o '${[^}]*}' | uniq | sed 's/${\(.*\)}/\1/g'); do echo $i; grep $i= kube-lustre-configurator.sh ;done
