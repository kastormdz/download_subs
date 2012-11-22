#!/bin/bash 
# 19/11/2012
#
# Author: Cristian Gimenez <cgimenez@gmail.com>
# Based on work of Roberto Muñoz Gomez <munoz.roberto@gmail.com>
#
# Description: Script to download subtitles of Tv Shows from subtitulos.es or any other
# webpage based on wikisubtitles
#
# Descripcion; Script para bajar subtitulos de series desde subtitulos.es o cualquier
# sitio basado en wikisubtitles
#
# *************************************
# NOTE: Only tested with subtitulos.es
# *************************************
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################ CONFIG ###########################################
export SERIES="/home/samba/series"
export LOGFILE="/tmp/subs.log"
export VERBOSE=1
export LOGG=0
export NEED=0

# Please check your language preference
################ CONFIG ###########################################

function download () {

################################################################################
# Language iteration list (blank separated). If first do not exists, try next. #
LANGUAGES="6 5 4"                                                              #
################################################################################

#Language list obtained from http://www.subtitulos.es/newsub.php
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

BASE="http://www.subtitulos.es"

chapterpage=$(mktemp)
trap "rm $chapterpage" 0
TOTAL="$#"
already_done=1
while [ "$1" ];do
	ORIGINAL_FILENAME="$(echo -e "$(echo $1|sed "s/%\([0-9a-fA-F][0-9a-fA-F]\)/\\\x\1/g")")" #Regenerating original filename from escaped chars
	DIR="$(dirname "$ORIGINAL_FILENAME")"
	if [ ! -d "$DIR" ];then
		logger "# Error trying to access to $DIR...skipping"
		sleep 5
		shift
		continue
	fi
	pushd "$DIR" &>/dev/null
	FILE="$(basename "$ORIGINAL_FILENAME")"
	logger "# ($already_done/$TOTAL) Parsing $FILE..."

	#Obtain a guessed show name from filename
	SHOW="$(echo "$FILE"|sed -e "s/^\(.*\)\.[sS][0-9]\+[eE][0-9]\+[\.-].*$/\1/g")" 
	SHOW=${SHOW//./-} #Blanks need to be translated to "-" and blanks are "." in filenames

	#Obtain a guesses chapter
	CHAPTER="$(echo "$FILE"|sed -e "s/.*[sS]\([0-9]\+\)[eE]\([0-9]\+\).*/\1x\2/g" )" #Parsing the chapter code to get something like 03x04

	SHOW_orig="$SHOW"
	for regexp_show in "" 's/-\([^-]*\)$/-(\1)/' 's/-[^-]*$//g';do
		# If first guess with show title is wrong, try put the last word between (). Very useful for shows like V.(2009) because in the filename doesn't appear the ()
		# Also try to download without the last word. For example for Thundercats-2011 y only want Thundercats.
		[ "$regexp_show" ] && SHOW="$(echo $SHOW_orig|sed $regexp_show)"

		logger "# ($already_done/$TOTAL) Downloading subtitle show $SHOW chapter $CHAPTER in directory $DIR ..."
		URLCHAPTER="$BASE/$SHOW/$CHAPTER"
		logger "# ($already_done/$TOTAL) Looking for the code of show $SHOW chapter $CHAPTER ..."
		wget -qO $chapterpage "$URLCHAPTER"
		chaptercode="$(cat $chapterpage |sed  -n "s/.*ajax_getComments.php?id=\([0-9]\+\).*/\1/gp")"
		[ "$chaptercode" ] && break || sleep 1
	done
	if [ -z "$chaptercode" ];then
		logger "# ($already_done/$TOTAL) Code for $SHOW $CHAPTER not found"
		sleep 1
	else
		logger "# ($already_done/$TOTAL) Found"
		for lang in $LANGUAGES;do
			#Check if translation is finished
			URLSUBTITLE="$BASE/updated/$lang/$chaptercode"
			if ! grep -q "$URLSUBTITLE" $chapterpage;then #If the subtitles are not completed...
				completed="$(grep -B10 "jointranslation.php?id=$chaptercode&fversion=[0-9]\+&lang=$lang" $chapterpage|grep -o "[^[:space:]]\+%")"
				if [ "$completed" ];then
					if dialog --yesno "Subtitle for $SHOW $CHAPTER in ${LANGUAGES_str[$lang]} is not complete. Only $completed is done." 7 60 ;then
						if wget -q -O "${FILE%.*}.srt" --referer="$URLCHAPTER" "$URLSUBTITLE/0" ;then
							logger "# ($already_done/$TOTAL) $SHOW $CHAPTER SUCCESS"
							break;
						else
							logger "# ($already_done/$TOTAL) $SHOW $CHAPTER FAIL"
							sleep 1
						fi
					fi
				fi
			else #If they are finished...
				url="$(grep -o "$URLSUBTITLE/[0-9]\+" $chapterpage|tail -1)"
				logger "# ($already_done/$TOTAL) Trying download show $SHOW chapter $CHAPTER in ${LANGUAGES_str[$lang]}..."
				if wget -q -O "${FILE%.*}.srt" --referer="$URLCHAPTER" "$url" ;then
					logger "# ($already_done/$TOTAL) $SHOW $CHAPTER SUCCESS"
					break;
				else
					logger "# ($already_done/$TOTAL) $SHOW $CHAPTER FAIL"
					sleep 1
				fi
			fi
		done
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
   
   if [ -f "$name" ] ; then
      EXIST=1
   else 
      EXIST=0
      cd "$p"
      logger "# Need SUB for $1"
      #convert format from 9X99 S99E99 & renaming
      #fixme ** bug with season >9 
      tmp=`echo $1 |  egrep -i '[1-9]x[0-9][1-9]' `
      if [ $tmp ] ; then
            #fixme better regex replace
            new=` echo $1 | sed 's/^\(.*\)\([0-9][Xx]\)\([0-9]\{2,2\}\)\(.*\)$/\1S0\2E\3\4/'| sed 's/xE/E/' `
            logger "# Converting to $new "
	    mv "$1" "$new"
            download "$new"
            ((NEED++))
      else
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
echo "Usage: download_subs.sh [tv_show_file] "
echo "[tv_show_file] is optional, by default it searchs "
echo "-l  verbose to logfile "
echo " "
exit
;;

esac

logger "##########################  Download Subs INIT ##########################"

if [ -f "$1" ] ; then
	logger "# Processing file $1 "
	chksub $1
	exit
fi

find $SERIES \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi \) -execdir bash -c 'chksub {}' \;

if [ $NEED == 0 ] ; then
	logger "# No need to download subs.. Everything is up-to-date. Bye."
fi

logger "##########################  Download Subs END  ##########################"




