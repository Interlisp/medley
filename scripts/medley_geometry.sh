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

if [ ${noscroll} = false ];
then
  scroll=22
else
  scroll=0
fi
if [[ -n ${geometry} && -n ${screensize} ]];
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [[ -z "${gw}" || -z "${gh}" ]];
  then
    echo "Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    echo "Exiting"
    exit 7
  fi
  geometry="-g ${geometry}"
  #
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [[ -z "${sw}" || -z "${sh}" ]];
  then
    echo "Error: Improperly formed -screensize argument: ${screensize}"
    echo "Exiting"
    exit 7
  fi
  screensize="-sc ${screensize}"
elif [[ -n ${geometry} ]];
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${gw}" -a -n "${gh}" ] ; then
    sw=$(( ((31+${gw})/32*32) - ${scroll} ))
    sh=$(( ${gh} - ${scroll} ))
    geometry="-g ${gw}x${gh}"
    screensize="-sc ${sw}x${sh}"
  else
    echo "Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    echo "Exiting"
    exit 7
  fi
elif [[ -n ${screensize} ]];
then
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${sw}" -a -n "${sh}" ] ; then
    sw=$(( (31+$sw)/32*32 ))
    gw=$(( ${scroll}+${sw} ))
    gh=$(( ${scroll}+${sh} ))
    geometry="-g ${gw}x${gh}"
    screensize="-sc ${sw}x${sh}"
  else
    echo "Error: Improperly formed -screensize argument: ${screensize}"
    echo "Exiting"
    exit 7
  fi
else
  screensize="-sc 1440x900"
  if [ ${noscroll} = false ];
  then
    geometry="-g 1462x922"
  else
    geometry="-g 1440x900"
  fi
fi
