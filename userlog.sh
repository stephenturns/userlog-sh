#!/bin/bash
#
# Stephen Turner
# *************************************************************************************************
# Variable Declaration

declare -rx last="/usr/bin/last"	# Last pointer
declare -i intI=0			# Integer - Counter variable
declare -i intD=0			# Integer - Array counter - arrDuration
declare -i intIndex=0			# Integer - Array counter
declare -i intVal=0			# Integer - Value to increment arrNumLogins
declare strScriptTitle=${0##*/}		# String - The script file name
declare strIn=$1			# String - User declared options
declare strGrep=			# String - Search params for arrUsers
declare strMonth=$2			# String - Month
declare strDay=$3			# String - Day
declare strHour=$4			# String - Hour
declare -a arrUsers			# Array - Username array
declare -a arrNumLogins			# Array - Number of user logins
declare -a arrDuration 			# Array - Duration of logins

# *************************************************************************************************
# Function Declaration

#funcUserList - Takes the output from Last -R and adds users, duration, login times to arrays for display 
function funcUserList {
echo - funcUserList - BEGIN
  echo " - joining params:"
  
  #Section 1 - Calculate the grep string for the search params 
  if [ "$strMonth" == "" ]; then		
      echo "$strScriptTitle:$LINENO: the Month value can not be nothing... aborting" >&2
      exit 1
  fi
  
  if [ "$strDay" == "" ]; then
      strGrep="$strMonth"
  fi
  
  if [ "$strDay" != "" ]; then
      strGrep="$strMonth $strDay"
  fi
  
  if [ "$strHour" != "" ] && [ "$strDay" != "" ]; then
      strGrep="$strMonth $strDay $strHour"
  fi
  
  if [ "$strHour" != "" ] && [ "$strDay" == "" ]; then
      strGrep="$strMonth * $strHour"
  fi  
  echo "  - params: $strGrep"
  
  #Section 2 - From the search params find and add the users, login sessions, and times to arrays
  echo " - listing users:"
 
  readout=$(last -R | awk '{print $1,$4,$5,$6,$8,$9}' | grep -i "$strGrep" | sort)
  
  #if $readout is empty - the search critera had 0 match so exit
  if [[ -z "$readout" ]]; then
    echo " - listing users end"
    echo - funcUserList - END
    echo;
    echo " 0 users found matching $strGrep"
    exit 1
  fi
  
  #While loop to iterate line by line the results of $readout
  while read line; do 
  #$line output offline session: user Aug 22 08:28 08:51 (00:23)
  #$line output online session: user Aug 22 08:28 logged in
   
  strUser=$(echo $line | awk '{print $1'})
  strDuration=$(echo $line | awk '{print $6'})
  
  #if not $strDuration equal to "in" then the session is not online
  if [ "$strDuration" != "in" ]; then
      strLoginDate=$(echo $line | awk '{print $2"."$3"."$4"-"$5}')
      strLoginDateDisplay=$(echo $line | awk '{print $2" "$3" "$4"-"$5}')      
  else # the session is online (logged in)
      #calculate the current time values to assign to $strLoginDate and $strLoginDateDisplay
      strLoginTime=$(echo $line | awk '{print $4}')
      intH=`echo $strLoginTime | awk -F ":" '{print $1}' | sed 's/^0//'`
      intM=`echo $strLoginTime | awk -F ":" '{print $2}' | sed 's/^0//'`      
      intMnow=$(date +%M)					
      intHnow=$(date +%H)
      strLoginDate=$(echo $line | awk '{print "LoggedIn-."$2"."$3"."$4"-"}')$intHnow:$intMnow
      strLoginDateDisplay=$(echo $line | awk '{print "Logged In - " $2" "$3" "$4"-"}')$intHnow:$intMnow    
      	      
      let "intThour=intHnow-intH"
      
      #if the user has been logged in for over an hour	  
      if [ $intThour -gt 0 ]; then
	let "intH=(intH*60)+intM"				
	let "intHnow=(intHnow*60)+intMnow"	
	let "intTMins=(intHnow-intH)" 		# the total minutes difference
	let "intHours=intTMins / 60" 		# the total hours
	let "intMins=intTMins-(intHours*60)"	# remainder minutes [not used]
      else
	let "intTMins=intMnow-intM"
      fi
      
      #if the values for hours and minutes are less then 10 then append a 0 to conform to formatting
      if [ $intHours -lt 10 ]; then
	intHours="0"$intHours
      fi
      
      if [ $intMins -lt 10 ]; then
	intMins="0"$intMins
      fi
      
      strDuration="($intHours:$intMins)"      
  fi
  
  #if the user is in the arrUsers array then increment the arrNumLogins array and arrDuration array.
  if (echo ${arrUsers[@]} | grep -wq $strUser); then
      let "intD=intIndex-1"
      intVal=`expr ${arrNumLogins[intIndex]}+1`
      arrNumLogins[intIndex]=$intVal
      arrDuration[intD]="${arrDuration[$intD]} $strLoginDate"."$strDuration"
      let "intVal+=1"    
      echo "   - [$intVal] $strLoginDateDisplay - $strDuration"   
   else # user is not in the arrUsers array.  Add the user and duration to same index number 
      arrUsers[intIndex]=$strUser
      arrDuration[intIndex]=$strLoginDate"."$strDuration
      echo "  - USER: $strUser" 
      echo "   - [1] $strLoginDateDisplay - $strDuration"
      let "intIndex+=1"
   fi
  done <<< "$(echo -e "$readout")"
  
echo - funcUserList - END  
}

declare -t funcUserList			# Function - Load users into arrUsers

#funcHelp - Usage information
function funcHelp {
  echo Usage:
  echo " userlog [-p] [-s] <month> <day> <hour> [-h]"
  echo " show the userlog for the month day hour."
  echo;
  echo "  -p, --prompt			prompt in script for month day hour value"
  echo "  -s, --set 			set month day hour values at command line"
  echo "  -h, --help			help menu"
  echo;
  echo Example:
  echo "  userlog -s Aug 15 23		show all users Aug 15 during the hour of 11pm"
  echo "  userlog -s Aug 15 09:00	show all users at 9:00am sharp"
  echo "  userlog -s Aug 15		show all users during Aug 15"
  echo "  userlog -s Aug		Show all users during Aug"
  exit 0
}

declare -t funcHelp			# Function - Load users into arrUsers


# *************************************************************************************************
# Sanity Checks

#if the last command is not available then exit
if test ! -x "$last" ; then
	printf "$strScriptTitle:$LINENO: the last command failed... aborting" >&2
	exit 1
fi

# *************************************************************************************************
# Main

#  $strIn=$1 - dertermine command line params
if [ "$strIn" == "-p" ] || [ "$strIn" == "--prompt" ]; then
    echo userlog:
    echo " please enter the search params"
    echo " to skip a param hit enter"
    echo;
    read -p "Enter Month [Aug]: " strMonth
    read -p "Enter Day [DD]: " strDay
    read -p "Enter Hour [HH]: " strHour
    funcUserList
elif [ "$strIn" == "-s" ] || [ "$strIn" == "--set" ]; then
    funcUserList
elif [ "$strIn" == "-h" ] || [ "$strIn" == "--help" ]; then
    funcHelp
elif [ -z "$strIn" ]; then
    funcHelp
else
   funcHelp
fi

#display the results of funcUserList
echo --------------------------------------------------------
echo "A total of [${#arrUsers[@]}] unique users during the period $strGrep"
intIndex=0
intTotal=0
intI=1
intD=1

for val in ${arrUsers[@]}; do
  echo " User[$intI]: $val"
  echo "      - login sessions ($strGrep)"
  
  #for each user output their login durations from arrDuration
  for dur in ${arrDuration[intIndex]}; do  
    #$dur offline output= Aug.22.11:27-19:34.(08:07)
    #$dur online output= LoggedIn-.Aug.25.16:52-18:17.(01:25)
    
    strDur=$(echo $dur | awk -F "." '{print $4}')
    
    #if $strDur begins '(' then this identifies an offline calculation
    if [[ $strDur = "("* ]]; then
	  strLoginDateDisplay=$(echo $dur | awk -F "." '{print $1" "$2" "$3}')
	  printf "       - [$intD] $strLoginDateDisplay $strDur" && echo $strDur | cut -c 2-6 | awk -F ":" '{min=$2;hour=$1;total=0}{total=(hour*60)+min} END {print " - " hour " hours " min " minutes ["total"min]" }'
	  intVal=`echo $strDur | cut -c 2-6 | awk -F ":" '{min=$2;hour=$1;total=0}{total=(hour*60)+min} END {print total}'`
	  let "intTotal+=intVal"
    else # an online calculation
	 strDur=$(echo $dur | awk -F "." '{print $5}') 
	 strLoginDateDisplay="Logged In - "$(echo $dur | awk -F "." '{print $2" "$3" "$4}')
	 intVal=`echo $strDur | cut -c 2-6 | awk -F ":" '{min=$2;hour=$1;total=0}{total=(hour*60)+min} END {print total}'`
	 let "intTotal+=intVal"
	 printf "       - [$intD] $strLoginDateDisplay $strDur" && echo $strDur | cut -c 2-6 | awk -F ":" '{min=$2;hour=$1;total=0}{total=(hour*60)+min} END {print " - " hour " hours " min " minutes ["total"min]" }'
    fi 
    intD=$intD+1
  done
  let "intH=intTotal / 60"
  let "intM=intTotal - (intH * 60)"
  echo "       - Total session duration = $intH hours $intM minutes"
  intIndex=$intIndex+1
  intI=$intI+1
  intD=1
  intTotal=0
done


# *************************************************************************************************
# Clean up
exit 0					# Exit with status 0
