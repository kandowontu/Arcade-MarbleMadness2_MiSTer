focus maincpu
do temp0=0
rp {++temp0>=#100000},{traceflush; quit}
trace roms/mm2_mame_instruction_trace.log,maincpu,noloop
go
