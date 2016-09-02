#!/usr/bin/bash 
# download_subs.sh
# 19/11/2012
# 08/03/2016
# 22/08/2016
# 30/08/2016
# Author: Cristian Gimenez <cgimenez@gmail.com>

################ CONFIG ################################################################################################
export SERIES_HOME="/home/samba/series/"
export VERBOSE=1
export code=0
export TOTAL=0
export SERIES_LIST="/tmp/series.html"
# Tratando de evitar el ban (no les gusta los scripts asi q nos identificamos como un browser mas..)
export AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.82 Safari/537.36"
export BASE="http://www.tusubtitulo.com"
#Orden de Lenguaje a Bajar
export LANGUAGES="6 5"  
############### CONFIG #################################################################################################

function download () {
 
#Listado de idiomas sacados de http://www.tusubtitulo.com/newsub.php
LANGUAGES_str[1]="English"
LANGUAGES_str[4]="Español"
LANGUAGES_str[5]="Español (España)"
LANGUAGES_str[6]="Español (Latinoamérica)"


chapterpage=$(mktemp)
trap "rm $chapterpage" 0

TOTAL="$#"
already_done=1
while [ "$1" ];do
	ORIGINAL_FILENAME="$(echo -e "$(echo $1|sed "s/%\([0-9a-fA-F][0-9a-fA-F]\)/\\\x\1/g")")" #Escapando los caracteres especiales
	DIR="$(dirname "$ORIGINAL_FILENAME")"
	if [ ! -d "$DIR" ];then
		sleep 5
		shift
		continue
	fi
	pushd "$DIR" &>/dev/null
	FILE="$(basename "$ORIGINAL_FILENAME")"
	SHOW="$(echo "$FILE"|sed -e "s/^\(.*\)\.[sS][0-9]\+[eE][0-9]\+[\.-].*$/\1/g")" 
	# --------- obteniendo codigo ---------------
	SHOWNAME=${SHOW//./ } 
	code="$(cat $SERIES_LIST | grep -o '<a .*href=.*>'| sed -e 's/<a/\n<a/g' | grep -i "$SHOWNAME" | tail -n 1 | cut -d / -f 3 | sed -e 's/\".*$//')"
	if [ "$code" == "" ] ; then
	       	echo "No se encontro codigo de serie >>>>$SHOWNAME<<<<< "
	fi
	# -------------------------------------------
	SHOW=${SHOW//./-} 
	# Formato de subtitulos.es
	CHAPTER="$(echo "$FILE"|sed -e "s/.*[sS]\([0-9]\+\)[eE]\([0-9]\+\).*/\1x\2/g" )" #Parseo de caps tipo 03x04
	SHOW="$(echo $SHOW | awk '{print tolower($0)}')"
        
	# Formato de tusubtitulo.com
	C2="$(echo "$CHAPTER" | sed -e "s/x/\//")"
	temporada="$(echo $C2 | cut -d "/" -f 1 | sed 's/^0//' )"
	capitulo="$(echo $C2 | cut -d "/" -f 2 | sed 's/^0//' )"

	SHOW_orig="$SHOW"
	for regexp_show in "" 's/-\([^-]*\)$/-(\1)/' 's/-[^-]*$//g';do
		# If first guess with show title is wrong, try put the last word between (). Very useful for shows like V.(2009) because in the filename doesn't appear the ()
		# Also try to download without the last word. For example for Thundercats-2011 y only want Thundercats.
		[ "$regexp_show" ] && SHOW="$(echo $SHOW_orig|sed $regexp_show)"
                  
		URLCHAPTER="$BASE/serie/$SHOW/$temporada/$capitulo/$code"  #tusubtitulo.com
		wget -qO $chapterpage "$URLCHAPTER" --user-agent="$AGENT"
		#chaptercode="$(cat $chapterpage |sed  -n "s/.*ajax_getComments.php?id=\([0-9]\+\).*/\1/gp")" #old subtitulo.es
		chaptercode="$(cat $chapterpage | grep subID | head -n1  | awk '{ print $4 }'| tr -d ';')" #fix tusubtitulo.com
		[ "$chaptercode" ] && break || sleep 1
	done

	if [ -z "$chaptercode" ] ; then
		echo "# ($already_done/$TOTAL) NO hay sub para $SHOW $CHAPTER"
		sleep 1
	else
		for lang in $LANGUAGES;do
			URLSUB="$(echo $BASE/updated/$lang/$chaptercode | xargs)"
			URLSUB2="$(echo updated/$lang/$chaptercode | xargs)"
			if ! $(grep --text -q $URLSUB2 $chapterpage) ; then # Si el sub no esta completado
				NOTD=1
				completed="$(grep --text -B15 "jointranslation.php?id=$chaptercode&amp;fversion=[0-9]\+&amp;lang=$lang" $chapterpage| grep --text -o "[^[:space:]]\+%")"
			else #Si esta listo
				url="$(grep --text -o  "$URLSUB2/[0-9]\+"  $chapterpage | tail -n 1)"
				echo -n "BAJANDO sub en ${LANGUAGES_str[$lang]} >>>> "
				if wget -q -O "${FILE%.*}.srt" --referer="$URLCHAPTER" "$BASE/$url" --user-agent="$AGENT"  ;then
					echo " SUCCESS"
					NOTD=0
					break;
				else
					echo -n " >>>>> $SHOW $CHAPTER FAIL <<<<"
					sleep 1
				fi
			fi
		done
	        if [ $NOTD == "1" ] ; then	
			echo " $completed traducido en ${LANGUAGES_str[$lang]}"
		fi
	fi
	popd &>/dev/null
	shift
	((already_done++))
done

}

function search(){
   p=$PWD
   ((TOTAL++))
   ignore=$p/"ignore"
   file=$(echo "$1" | sed 's/mp4//'  | sed 's/srt//' | sed 's/mkv//' | sed 's/avi//' )
   name=$file"srt"
   if [ ! -f "$ignore" ] ; then 
      if [ ! -f "$name" ] ; then 
  	   echo "# No existe sub para: $1"
      fi
   fi
}

function chksub(){
   p=$PWD
   file=$(echo "$1" | sed 's/mp4//'  | sed 's/srt//' | sed 's/mkv//' | sed 's/avi//' )
   name=$file"srt"
   EXIST="0"
   NEED="0"
   ((TOTAL++))
   #Crear con un "touch ignore" en el directorio de la serie para q no te baje subs de ahi
   ignore=$p/"ignore"

   if [ -f "$ignore" ] ; then 
	   EXIST=1 
   fi
   if [ -f "$name" ] ; then 
	   EXIST=1
   fi

   if [ $EXIST == "0" ] ; then 
      
      cd "$p"
      echo -n "# Procesando $1 >> "

      tmp=$(echo $1 |  egrep -i '[1-9]x[0-9][1-9]')
      if [ $tmp ] ; then
            #fixme better regex replace
	    #format 9X00
            new=` echo $1 | sed 's/^\(.*\)\([0-9][Xx]\)\([0-9]\{2,2\}\)\(.*\)$/\1S0\2E\3\4/'| sed 's/xE/E/' `
	    mv "$1" "$new" 
            download "$new"
            ((NEED++))
	    bajado=1
      fi
      #convert format from 9X99 S99E99 & renaming
      #fixme ** bug con temporada >9  por ej Bones
      tmp=$(echo $1 |  egrep -i '[1-9][0-9][0-9]\.')
      if [ $tmp ] ; then
	   #format 900
	   new=$(echo $1 | sed 's/^\(.*\)\.\([0-9]\)\([0-9]\{2,2\}\)\(.*\)$/\1.S0\2E\3\4/'| sed 's/xE/E/')
	    if [ "$1" != "$new" ] ; then
               echo "# Convirtiendo a  $new "
	       mv $1 $new
            fi
            download "$new"
            ((NEED++))
	    bajado=1
      fi

      if ! [ $bajado ] ; then 
	   ((NEED++))
           download "$1" 
      fi	   
   
   fi

}

#MAIN################

export -f download
export -f chksub 
export -f search

case "$1" in '-l')
 VERBOSE=1
;;
'--help')
clear
echo "download_subs.sh Help "
echo "                   "
echo "Uso: download_subs.sh [capitulo de la serie] (solo baja el sub del episodio indicado) "
echo "Uso: download_subs.sh [capitulo de la serie] [url del sub directo] (baja directamente el sub del link)"
echo "Uso: download_subs.sh search (solo muestra los subs que faltan)"
echo "Uso: download_subs.sh (busca y trata de bajar todos los subs -default-)"
echo " "
exit
;;

esac

# soporte download directo pasando la url del sub
if [ "$2" != "" ] ; then
	# podes pasar el link directo del sub para q lo baje y lo renombre en caso de no encontrarlo
	# formato: https://www.tusubtitulo.com/updated/6/51185/0
	file=$(echo "$1" | sed 's/mp4//' | sed 's/mkv//' | sed 's/avi//')
	name=$file"srt"
	wget -q -O "$name" "$2" --referer $BASE  --user-agent="$AGENT"
	exit
fi

if [ "$1" == "search" ] ; then
   if [ -d "$SERIES_HOME" ] ; then
      find "$SERIES_HOME" \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi \) -execdir bash -c "search {}" \; 2>/dev/null
   else
	echo "No existe DIR: $SERIES_HOME  para buscar subtitulos.. Editar en CONFIG"
   fi
   echo "Total de archivos procesados: $TOTAL"
   exit
fi

# Tratando de obtener la lista de codigos 
if [  -f "$SERIES_LIST" ] ; then
	# Resfrescando la lista 1 dia, por si hay series nuevas
	find $SERIES_LIST -mtime +1 -exec rm -f {} \;
fi	
if [ ! -f "$SERIES_LIST" ] ; then
   wget http://tusubtitulo.com/series.php -qO $SERIES_LIST --user-agent="$AGENT"
fi


if [ -f "$1" ] ; then
	chksub $1
	exit
fi

if [ -d "$SERIES_HOME" ] ; then
   find "$SERIES_HOME" \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi \) -execdir bash -c "chksub {}" \; 2>/dev/null
else
	echo "No existe DIR: $SERIES_HOME  para buscar subtitulos.. Editar en CONFIG"
fi
echo "Total de archivos procesados: $TOTAL"
