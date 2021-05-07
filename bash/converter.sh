mp3() {
	filename=$(echo "$1" | cut -f 1 -d '.')

	ffmpeg -v 5 -y -i $filename.m4a -acodec libmp3lame -ac 2 -ab 192k $filename.mp3 && rm $filename.m4a
}
