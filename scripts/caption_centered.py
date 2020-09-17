#inspired from   https://github.com/fedecalendino/pysub-parser/blob/master/pysubparser/parsers/srt.py	 

from datetime import datetime

  			   
TIMESTAMP_SEPARATOR = ' --> '
TIMESTAMP_FORMAT = '%H:%M:%S,%f'


def parse_timestamps(line):
	try:
		start, end = line.split(TIMESTAMP_SEPARATOR)

		start = datetime.strptime(start, TIMESTAMP_FORMAT).time()
		end = datetime.strptime(end, TIMESTAMP_FORMAT).time()

		return start, end	
	except:
		pass

count = 100
with open('lyrics.srt','r') as f:
	lines_with_times = []
	lines_with_texts = []
	
	for ind,line in enumerate(f):
		line = line.rstrip()
		
		if TIMESTAMP_SEPARATOR in line:
			lines_with_times.append(ind)
			start, end = parse_timestamps(line)
			#start.minute, start.second
			with open(f'../media/lyrics/timing/text_{count}_1.txt', 'w') as s:
				start_second = start.minute*60 + start.second + start.microsecond/10**6
				s.write(str(start_second))
			
			with open(f'../media/lyrics/timing/text_{count}_2.txt', 'w') as e:
				end_second = end.minute*60 + end.second + end.microsecond/10**6
				e.write(str(end_second))
			count+=1



for i,time_ind in enumerate(lines_with_times):
	if i%2==0:
		lines_with_texts.append(time_ind-2)
		lines_with_texts.append(time_ind+1)
	else:
		lines_with_texts.append(time_ind-2)
		lines_with_texts.append(time_ind+1)
lines_with_texts.pop(0)


with open('lyrics.srt','r') as f:
	lyrics_l=f.readlines()
	lyrics_l.append(' ')


# temp = 0
# for n in range(100,count-1):
# 	with open(f'../media/lyrics/text_{n}.txt', 'w') as f:
# 		f.writelines(lyrics_l[lines_with_texts[temp]:lines_with_texts[temp+1]])
# 		temp+=2

# with open(f'../media/lyrics/text_{count-1}.txt', 'w') as f:
# 		f.writelines(lyrics_l[lines_with_texts[-1]:])




temp = 0
for n in range(100,count-1):
	with open(f'../media/lyrics/text_{n}.txt', 'w') as f:
		# l1_len = 0
		max_length = max([len(l) for l in lyrics_l[lines_with_texts[temp]:lines_with_texts[temp+1]]])
		sen_l = []
		for l in lyrics_l[lines_with_texts[temp]:lines_with_texts[temp+1]]:
			# sen_l.append(' '*int(max(0,((l1_len-len(l))/2)))+l)
			sen_l.append(' '*int(((max_length-len(l))/2))+l)
			# l1_len = max(len(l),l1_len)

		f.writelines(sen_l)
		temp+=2

with open(f'../media/lyrics/text_{count-1}.txt', 'w') as f:
		# l1_len = 0
		max_length = max([len(l) for l in lyrics_l[lines_with_texts[-1]:]])
		sen_l = []
		for l in lyrics_l[lines_with_texts[-1]:]:
			# sen_l.append(' '*int(max(0,((l1_len-len(l))/2)))+l)
			sen_l.append(' '*int(((max_length-len(l))/2))+l)
			# l1_len = max(len(l),l1_len)
		f.writelines(sen_l)
		

# max([len(l) for l in lyrics_l[lines_with_texts[temp]:lines_with_texts[temp+1]]])






		
		


