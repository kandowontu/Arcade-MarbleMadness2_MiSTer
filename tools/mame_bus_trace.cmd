focus maincpu
do temp0=0
wp 0:maincpu,1000000,r,1,{logerror "R,%06X\n",wpaddr ; temp0++ ; go}
wp 0:maincpu,1000000,w,1,{logerror "W,%06X,%X\n",wpaddr,wpdata ; temp0++ ; go}
rp {temp0>=#100000},{quit}
go
