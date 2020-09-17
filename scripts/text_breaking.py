#READ THE FILE
with open('text.txt', 'r') as f:
	lines = f.readlines()

#GET EACH LINE
#for i,line in enumerate(lines,100):
#	with open(f'../media/{i}.txt', 'w') as f:
#		f.writelines([l+'\n'for l in line.replace('\n','').split('\\n')])

for i,line in enumerate(lines,100):
	with open(f'../media/{i}.txt', 'w') as f:
		l1_len = 0
		sen_l = []
		for l in line.replace('\n','').split('\\n'):
			sen_l.append(' '*int(max(0,((l1_len-len(l))/2)))+l+'\n')
			l1_len = len(l)

		f.writelines(sen_l)
		
