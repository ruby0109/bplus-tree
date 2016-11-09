reset
set ylabel 'time(sec)'
set style fill solid
set title 'perfomance comparison'
set term png enhanced font 'Verdana,10'
set output 'runtime.png'

plot [:][:80]'output.txt' using 2:xtic(1) with histogram title 'original', \
'' using ($0-0.2):($2+4):2 with labels title ' ', \
'' using 3:xtic(1) with histogram title 'optimized'  , \
'' using ($0):($3+1):3 with labels title ' ', \
'' using 4:xtic(1) with histogram title 'B+ tree' , \
'' using ($0+0.35):($4+3):4 with labels title ' ', \
'' using 5:xtic(1) with histogram title 'B+ tree with bulk loading' , \
'' using ($0+0.45):($5+5):5 with labels title ' ', \
