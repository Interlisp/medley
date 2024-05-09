#!only-to-be-sourced
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2269
###############################################################################
#
#    medley_geometry.sh - script for computing the geometry and screensize
#                         parameters for a medley session
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-17 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

if [ "${noscroll}" = false ];
then
  scroll=22
else
  scroll=0
fi
if [ -n "${geometry}" ] && [ -n "${screensize}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${gw}" ] || [ -z "${gh}" ]
  then
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
  geometry="${geometry}"
  #
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${sw}" ] || [ -z "${sh}" ]
  then
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
  screensize="${screensize}"
elif [ -n "${geometry}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${gw}" ] && [ -n "${gh}" ]
  then
    sw=$(( (((31+gw)/32)*32)-scroll ))
    sh=$(( gh - scroll ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
elif [ -n "${screensize}" ]
then
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${sw}" ] && [ -n "${sh}" ]
  then
    sw=$(( (31+sw)/32*32 ))
    gw=$(( scroll+sw ))
    gh=$(( scroll+sh ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
else
  screensize="1440x900"
  if [ "${noscroll}" = false ];
  then
    geometry="1462x922"
  else
    geometry="1440x900"
  fi
fi
