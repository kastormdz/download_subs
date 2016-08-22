#!/usr/bin/bash 
# 19/11/2012
# 08/03/2016
# 22/08/2016
# Author: Cristian Gimenez <cgimenez@gmail.com>
#
################ CONFIG ###########################################
export SERIES="/home/samba/series/"
export LOGFILE="/tmp/subs.log"
export VERBOSE=1
export LOGG=0
export NEED=0
export code=0
################ CONFIG ###########################################


########################################################################
# FIXME: tenes que crear un archivo de nombre serie
#        en el directorio de la serie conteniendo el codigo de la serie
#        sacado de https://www.tusubtitulo.com/series.php
########################################################################


function download () {


LANGUAGES="6 5"                                                              #

#Listado de idiomas sacados de http://www.tusubtitulo.com/newsub.php
LANGUAGES_str[1]="English"
LANGUAGES_str[10]="Brazilian"
LANGUAGES_str[11]="German"
LANGUAGES_str[12]="Català"
LANGUAGES_str[13]="Euskera"
LANGUAGES_str[14]="Czech"
LANGUAGES_str[15]="Galego"
LANGUAGES_str[16]="Turkish"
LANGUAGES_str[17]="Nederlandse"
LANGUAGES_str[18]="Swedish"
LANGUAGES_str[19]="Russian"
LANGUAGES_str[4]="Español"
LANGUAGES_str[5]="Español (España)"
LANGUAGES_str[6]="Español (Latinoamérica)"
LANGUAGES_str[7]="Italian"
LANGUAGES_str[8]="French"
LANGUAGES_str[9]="Portuguese"
LANGUAGES_str[20]="Hungarian"
LANGUAGES_str[21]="Polish"
LANGUAGES_str[22]="Slovenian"
LANGUAGES_str[23]="Hebrew"
LANGUAGES_str[24]="Chinese"
LANGUAGES_str[25]="Slovak"

AGENT2="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.75 Safari/537.36"
AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.75 Safari/537.36"
BASE="http://www.tusubtitulo.com"

chapterpage=$(mktemp)
trap "rm $chapterpage" 0

#chapterpage=/tmp/sub.dat
#> $chapterpage
#set -x
TOTAL="$#"
already_done=1
while [ "$1" ];do
	ORIGINAL_FILENAME="$(echo -e "$(echo $1|sed "s/%\([0-9a-fA-F][0-9a-fA-F]\)/\\\x\1/g")")" #Escapando los caracteres especiales
	DIR="$(dirname "$ORIGINAL_FILENAME")"
	if [ ! -d "$DIR" ];then
		logger "# Error en  $DIR "
		sleep 5
		shift
		continue
	fi
	pushd "$DIR" &>/dev/null
	FILE="$(basename "$ORIGINAL_FILENAME")"
	#logger "# ($already_done/$TOTAL) Parsing $FILE..."
	SHOW="$(echo "$FILE"|sed -e "s/^\(.*\)\.[sS][0-9]\+[eE][0-9]\+[\.-].*$/\1/g")" 
	SHOW=${SHOW//./-} 

	#Formato de subtitulos.es
	CHAPTER="$(echo "$FILE"|sed -e "s/.*[sS]\([0-9]\+\)[eE]\([0-9]\+\).*/\1x\2/g" )" #Parseo de caps tipo 03x04

	SHOW="$(echo $SHOW | awk '{print tolower($0)}')"
        
	#Formato de tusubtitulo.com
	C2="$(echo "$CHAPTER" | sed -e "s/x/\//")"
	temporada="$(echo $C2 | cut -d "/" -f 1 | sed 's/^0//' )"
	capitulo="$(echo $C2 | cut -d "/" -f 2 | sed 's/^0//' )"

	#set -x
	SHOW_orig="$SHOW"
	for regexp_show in "" 's/-\([^-]*\)$/-(\1)/' 's/-[^-]*$//g';do
		# If first guess with show title is wrong, try put the last word between (). Very useful for shows like V.(2009) because in the filename doesn't appear the ()
		# Also try to download without the last word. For example for Thundercats-2011 y only want Thundercats.
		[ "$regexp_show" ] && SHOW="$(echo $SHOW_orig|sed $regexp_show)"
                  
		URLCHAPTER="$BASE/serie/$SHOW/$temporada/$capitulo/$code"  #tusubtitulo.com
		wget -qO $chapterpage "$URLCHAPTER" --user-agent="$AGENT"
		cat $chapterpage > /tmp/sub.txt
		#echo $URLCHAPTER
		#chaptercode="$(cat $chapterpage |sed  -n "s/.*ajax_getComments.php?id=\([0-9]\+\).*/\1/gp")"
		chaptercode="$(cat $chapterpage | grep subID | head -n1  | awk '{ print $4 }'| tr -d ';')"
		[ "$chaptercode" ] && break || sleep 1
		#echo $chaptercode
		#exit
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
				#echo "## $URLSUB ## $url ##"
				#exit
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

function logger() {
 timestamp=$(date "+%d/%m/%Y %H:%M")
 if [ $LOGG == 1 ] ; then
	 echo "$timestamp  $1 " >> $LOGFILE
 fi

 if [ $VERBOSE == 1 ] ; then
    echo "$timestamp  $1 "
 fi
}

function chksub()
{
   p=$PWD
   file=`echo "$1" | sed 's/mp4//'  | sed 's/srt//' | sed 's/mkv//' | sed 's/avi//' `
   name=$file"srt"
   EXIST="0"
   ignore=$p/"ignore"

   if [ -f "../../serie" ] ; then
	   code=`cat ../../serie`
   else
        if [ -f "../serie" ] ; then
	  code=`cat ../serie`
        fi
   fi
 
   if [ $code == "0" ] ; then
	   EXIST=1
	   #echo "#  No SERIE CODE for $1 #######################################"
   fi

   if [ -f "$ignore" ] ; then
      EXIST=1
   fi

   if [ -f "$name" ] ; then
      EXIST=1
   fi

   if [ $EXIST == "0" ] ; then 
      
      cd "$p"
      echo -n "# Procesando $1 >> "

      tmp=`echo $1 |  egrep -i '[1-9]x[0-9][1-9]' `
      if [ $tmp ] ; then
            #fixme better regex replace
	    #format 9X00
            new=` echo $1 | sed 's/^\(.*\)\([0-9][Xx]\)\([0-9]\{2,2\}\)\(.*\)$/\1S0\2E\3\4/'| sed 's/xE/E/' `
            logger "# Converting to $new "
	    mv "$1" "$new" 
            download "$new"
            ((NEED++))
	    bajado=1
      fi
      #convert format from 9X99 S99E99 & renaming
      #fixme ** bug with season >9 
      tmp=`echo $1 |  egrep -i '[1-9][0-9][0-9]\.' `
      if [ $tmp ] ; then
	   #format 900
	    new=`echo $1 | sed 's/^\(.*\)\.\([0-9]\)\([0-9]\{2,2\}\)\(.*\)$/\1.S0\2E\3\4/'| sed 's/xE/E/' `
	    if [ "$1" != "$new" ] ; then
               echo "# Converting to $new "
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

export -f logger
export -f download
export -f chksub 

case "$1" in '-l')
 VERBOSE=1
;;
'--help')
echo "Download Subs Help "
echo "                   "
echo "Uso: download_subs.sh [capitulo de la serie] "
echo " "
exit
;;

esac


if [ -f "$1" ] ; then
	chksub $1
	exit
fi

find $SERIES \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi \) -execdir bash -c "chksub {}" \; 2>/dev/null






