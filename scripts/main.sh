#!/bin/bash
#
# Copyright (c) 2017-2019, Taner Sener (https://github.com/tanersener)
#
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.
#

# SCRIPT OPTIONS - CAN BE MODIFIED
WIDTH=1280
HEIGHT=720
FPS=30
TRANSITION_DURATION=1
IMAGE_DURATION=2
SCREEN_MODE=2               # 1=CENTER, 2=CROP, 3=SCALE, 4=BLUR
BACKGROUND_COLOR="black"

IFS=$'\t\n'                 # REQUIRED TO SUPPORT SPACES IN FILE NAMES

# FILE OPTIONS
# FILES=`find ../media/*.jpg | sort -r`             # USE ALL IMAGES UNDER THE media FOLDER SORTED
# FILES=('../media/1.jpg' '../media/2.jpg')         # USE ONLY THESE IMAGE FILES
FILES=`find ../media/*.jpg`                         # USE ALL IMAGES UNDER THE media FOLDER
python caption_centered.py                          # RUN THE PYTHON SCRIPT TO CREATE RELEVANT TEMPORALY TEXT FILES
TEXT_FILES=`find ../media/lyrics/*.txt | sort `	    # USE ALL TEXT FILES IN media FOLDER SORTED
AUDIO_FILE=`find ../media/*.mp3`                    # USE THE AUDIO FILE IN media FOLDER

############################
# DO NO MODIFY LINES BELOW
############################

# CALCULATE LENGTH MANUALLY
let IMAGE_COUNT=0
for IMAGE in ${FILES[@]}; do (( IMAGE_COUNT+=1 )); done

if [[ ${IMAGE_COUNT} -lt 2 ]]; then
    echo "Error: media folder should contain at least two images"
    exit 1;
fi

#CALCULATE IMAGE_DURATION TO ADJUST TO THE WHOLE SONG
SONG_DURATION=$(ffprobe -i ${AUDIO_FILE} -show_entries format=duration -v quiet -of csv="p=0")
IMAGE_DURATION=$((((${SONG_DURATION%.*}+$TRANSITION_DURATION)/$IMAGE_COUNT)-$TRANSITION_DURATION))


# INTERNAL VARIABLES
TRANSITION_FRAME_COUNT=$(( TRANSITION_DURATION*FPS ))
IMAGE_FRAME_COUNT=$(( IMAGE_DURATION*FPS ))
TOTAL_DURATION=$(( (IMAGE_DURATION+TRANSITION_DURATION)*IMAGE_COUNT - TRANSITION_DURATION ))
TOTAL_FRAME_COUNT=$(( TOTAL_DURATION*FPS ))

echo -e "\nVideo Slideshow Info\n------------------------\nImage count: ${IMAGE_COUNT}\nDimension: ${WIDTH}x${HEIGHT}\nFPS: ${FPS}\nImage duration: ${IMAGE_DURATION} s\n\
Transition duration: ${TRANSITION_DURATION} s\nTotal duration: ${TOTAL_DURATION} s\nTotal Frame Count: ${TOTAL_FRAME_COUNT} \n" 

START_TIME=$SECONDS

# 1. START COMMAND
FULL_SCRIPT="ffmpeg -y "
TEXT_SCRIPT="ffmpeg -y "
AUDIO_SCRIPT="ffmpeg -y "

# 2. ADD INPUTS
for IMAGE in ${FILES[@]}; do
    FULL_SCRIPT+="-loop 1 -i '${IMAGE}' "
done

# 3. START FILTER COMPLEX
FULL_SCRIPT+="-filter_complex \""

# 4. PREPARE INPUTS
for (( c=0; c<${IMAGE_COUNT}; c++ ))
do
    case ${SCREEN_MODE} in
        1)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        2)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,${WIDTH})':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),${HEIGHT},-1)',crop=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        3)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        4)
            FULL_SCRIPT+="[${c}:v]scale=${WIDTH}x${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,boxblur=100,setsar=sar=1/1[stream${c}blurred];"
            FULL_SCRIPT+="[${c}:v]scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba[stream${c}raw];"
            FULL_SCRIPT+="[stream${c}blurred][stream${c}raw]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:format=rgb,setpts=PTS-STARTPTS,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
    esac
done

# 5. APPLY PADDING
for (( c=1; c<=${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}out1]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${IMAGE_DURATION},select=lte(n\,${IMAGE_FRAME_COUNT})[stream${c}overlaid];"
    if [[ ${c} -eq 1 ]]; then
        if  [[ ${IMAGE_COUNT} -gt 1 ]]; then
            FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT})[stream${c}ending];"
        fi
    elif [[ ${c} -lt ${IMAGE_COUNT} ]]; then
        FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT}),split=2[stream${c}starting][stream${c}ending];"
    elif [[ ${c} -eq ${IMAGE_COUNT} ]]; then
        FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT})[stream${c}starting];"
    fi
done

# 6. CREATE TRANSITION FRAMES
for (( c=1; c<${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream$((c+1))starting][stream${c}ending]blend=all_expr='A*(if(gte(T,${TRANSITION_DURATION}),1,T/${TRANSITION_DURATION}))+B*(1-(if(gte(T,${TRANSITION_DURATION}),1,T/${TRANSITION_DURATION})))',select=lte(n\,${TRANSITION_FRAME_COUNT})[stream$((c+1))blended];"
done

# 7. BEGIN CONCAT
for (( c=1; c<${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}overlaid][stream$((c+1))blended]"
done

# 8. END CONCAT
FULL_SCRIPT+="[stream${IMAGE_COUNT}overlaid]concat=n=$((2*IMAGE_COUNT-1)):v=1:a=0[test];"


#new
FULL_SCRIPT+="[test]format=yuv420p[video]\""


# 9. END  
FULL_SCRIPT+=" -map [video] -vsync 2 -async 1 -rc-lookahead 0 -g 0 -profile:v main -level 42 -c:v libx264 -r ${FPS} ../temp2.mp4"

eval ${FULL_SCRIPT}


#ADD AUDIO
AUDIO_SCRIPT+=" -i ../temp2.mp4 -i ${AUDIO_FILE} -map 0:v -map 1:a -c copy -shortest ../temp.mp4"

eval ${AUDIO_SCRIPT}


# 10.ADD TEXT

#-------------------------------
TEXT_SCRIPT+="-i ../temp.mp4 -filter_complex \""

echo -e "\nSCRIPT FOR READING A FILE LINE BY LINE\n"

text_end_time=1		 #FIRST TEXT STARTING TIME-text_interval
TEXT_DURATION=8               #DURATION OF A SINGLE TEXT
text_interval=1          #INTERVAL BETWEEN 2 DIFFERENT TEXTS

# CALCULATE LINES MANUALLY
let LINE_COUNT=0
for LINE in ${TEXT_FILES[@]}; do (( LINE_COUNT+=1 )); done

TEXT_DURATION=$((((${SONG_DURATION%.*}+$text_end_time)/$LINE_COUNT)-$text_interval))


n=1

# 2. ADD INPUTS
#for TEXT in ${TEXT_FILES[@]}; do
#	text_start_time=$(($text_end_time+$text_interval))
#	text_end_time=$(($text_start_time+$TEXT_DURATION))

#	TEXT_SCRIPT+="[0]drawtext=textfile='${TEXT}':fontsize=50:fontfile=RoughOTF.otf:fontcolor=white:x=(w-tw)/2:y=(h-th)/2:enable='between(t,$text_start_time,$text_end_time)',fade=t=in:start_time=$(($text_start_time-0.2)):d=0.2:alpha=1,fade=t=out:start_time=$(($text_end_time-0.2)):d=0.2:alpha=1[fg$n];"
#	n=$((n+1))

#done

subtitle_offset=0

for (( c=100; c<$(($LINE_COUNT+100)); c++ ))
do
	text_start_time_n_adjust=$(<../media/lyrics/timing/text_${c}_1.txt)
	text_end_time_n_adjust=$(<../media/lyrics/timing/text_${c}_2.txt)
	text_start_time=$(echo $text_start_time_n_adjust-$subtitle_offset | bc)
	text_end_time=$(echo $text_end_time_n_adjust-$subtitle_offset | bc)

	TEXT_SCRIPT+="[0]drawtext=textfile=../media/lyrics/text_${c}.txt:fontsize=50:fontfile=RoughOTF.otf:fontcolor=white:x=(w-tw)/2:y=(h-th)/2:enable='between(t,$text_start_time,$text_end_time)',fade=t=in:start_time=$text_start_time:d=1:alpha=1,fade=t=out:start_time=$(echo $text_end_time-0.2 | bc):d=0.2:alpha=1[fg$n];"
	n=$((n+1))

done


TEXT_SCRIPT+="[0][fg1]overlay[out1];"

for (( c=1; c<$((n-2)); c++ ))
do
    TEXT_SCRIPT+="[out${c}][fg$((c+1))]overlay[out$((c+1))];"
done

TEXT_SCRIPT+="[out$((n-2))][fg$((n-1))]overlay\" -c:a copy ../lyrics_test1.mp4"

#-------------------------------



eval ${TEXT_SCRIPT}

eval $"rm ../temp.mp4"
eval $"rm ../temp2.mp4"
#rm ${TEXT_FILES[@]}


ELAPSED_TIME=$(($SECONDS - $START_TIME))

echo -e '\nSlideshow created in '$ELAPSED_TIME' seconds\n'

echo -e "\n $FULL_SCRIPT \n"

echo -e "\n $TEXT_SCRIPT \n"

unset $IFS