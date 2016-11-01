reset
set ylabel 'time(sec)'
set style fill solid
set title 'perfomance comparison'
set term png enhanced font 'Verdana,10'
set output 'runtime.png'

plot [:][:40]'output.txt' using 2:xtic(1) with histogram title 'original', \
'' using ($0-0.06):($2+1):2 with labels title ' ', \
'' using 4:xtic(1) with histogram title 'B+tree'  , \
'' using ($0+0.3):($3+3):4 with labels title ' ', \
#'' using 4:xtic(1) with histogram title 'B+tree' , \
#'' using ($0+0.01):($4+0.0025):4 with lables title ' ', \

